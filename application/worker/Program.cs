using System;
using System.Data.Common;
using System.Threading;
using Newtonsoft.Json;
using Npgsql;
using StackExchange.Redis;

namespace Worker
{
    public class Program
    {
        public static int Main(string[] args)
        {
            try
            {
                // Read environment variables
                var postgresHost =
                    Environment.GetEnvironmentVariable("POSTGRES_HOST");

                var postgresUser =
                    Environment.GetEnvironmentVariable("POSTGRES_USER");

                var postgresPassword =
                    Environment.GetEnvironmentVariable("POSTGRES_PASSWORD");

                var redisHost =
                    Environment.GetEnvironmentVariable("REDIS_HOST");

                Console.WriteLine($"POSTGRES_HOST: {postgresHost}");
                Console.WriteLine($"POSTGRES_USER: {postgresUser}");
                Console.WriteLine($"REDIS_HOST: {redisHost}");

                if (string.IsNullOrWhiteSpace(postgresHost) ||
                    string.IsNullOrWhiteSpace(postgresUser) ||
                    string.IsNullOrWhiteSpace(postgresPassword))
                {
                    Console.Error.WriteLine(
                        "PostgreSQL environment variables are missing."
                    );

                    return 1;
                }

                if (string.IsNullOrWhiteSpace(redisHost))
                {
                    Console.Error.WriteLine(
                        "REDIS_HOST environment variable is missing."
                    );

                    return 1;
                }

                // ---------------------------------------------------------
                // PostgreSQL
                // ---------------------------------------------------------

                var pgsql = OpenDbConnection(
                    postgresHost,
                    postgresUser,
                    postgresPassword
                );

                // ---------------------------------------------------------
                // Redis
                // ---------------------------------------------------------

                var redisConn = OpenRedisConnection(redisHost);

                var redis = redisConn.GetDatabase();

                // PostgreSQL keep-alive
                var keepAliveCommand = pgsql.CreateCommand();
                keepAliveCommand.CommandText = "SELECT 1";

                var definition = new
                {
                    vote = "",
                    voter_id = ""
                };

                // ---------------------------------------------------------
                // Main worker loop
                // ---------------------------------------------------------

                while (true)
                {
                    // Prevent excessive CPU usage
                    Thread.Sleep(100);

                    // Reconnect Redis if connection is lost
                    if (redisConn == null || !redisConn.IsConnected)
                    {
                        Console.WriteLine("Redis connection lost.");
                        Console.WriteLine("Reconnecting Redis...");

                        redisConn = OpenRedisConnection(redisHost);

                        redis = redisConn.GetDatabase();
                    }

                    // Get vote from Redis
                    string json =
                        redis.ListLeftPopAsync("votes").Result;

                    if (json != null)
                    {
                        var vote =
                            JsonConvert.DeserializeAnonymousType(
                                json,
                                definition
                            );

                        if (vote == null)
                        {
                            Console.Error.WriteLine(
                                "Could not deserialize vote."
                            );

                            continue;
                        }

                        Console.WriteLine(
                            $"Processing vote for '{vote.vote}' " +
                            $"by '{vote.voter_id}'"
                        );

                        // Reconnect PostgreSQL if connection is lost
                        if (pgsql.State !=
                            System.Data.ConnectionState.Open)
                        {
                            Console.WriteLine(
                                "PostgreSQL connection lost."
                            );

                            Console.WriteLine(
                                "Reconnecting PostgreSQL..."
                            );

                            pgsql = OpenDbConnection(
                                postgresHost,
                                postgresUser,
                                postgresPassword
                            );
                        }

                        // Store vote
                        UpdateVote(
                            pgsql,
                            vote.voter_id,
                            vote.vote
                        );
                    }
                    else
                    {
                        // Keep PostgreSQL connection alive
                        try
                        {
                            keepAliveCommand.ExecuteNonQuery();
                        }
                        catch (Exception ex)
                        {
                            Console.Error.WriteLine(
                                $"PostgreSQL keep-alive failed: " +
                                $"{ex.Message}"
                            );

                            try
                            {
                                pgsql.Close();
                            }
                            catch
                            {
                                // Ignore close error
                            }

                            pgsql = OpenDbConnection(
                                postgresHost,
                                postgresUser,
                                postgresPassword
                            );

                            keepAliveCommand =
                                pgsql.CreateCommand();

                            keepAliveCommand.CommandText =
                                "SELECT 1";
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(
                    "Worker stopped because of an unexpected error:"
                );

                Console.Error.WriteLine(ex);

                return 1;
            }
        }

        // ================================================================
        // PostgreSQL connection
        // ================================================================

        private static NpgsqlConnection OpenDbConnection(
            string host,
            string username,
            string password)
        {
            NpgsqlConnection connection;

            /*
             * IMPORTANT:
             *
             * RDS database name = voting
             *
             * SSL is required.
             *
             * Trust Server Certificate=true prevents the certificate
             * validation error we encountered with the RDS certificate.
             */

            string connectionString =
                $"Server={host};" +
                $"Database=voting;" +
                $"Username={username};" +
                $"Password={password};" +
                $"Ssl Mode=Require;" +
                $"Trust Server Certificate=true;";

            Console.WriteLine(
                "Connecting to PostgreSQL database 'voting'..."
            );

            while (true)
            {
                try
                {
                    connection =
                        new NpgsqlConnection(connectionString);

                    connection.Open();

                    break;
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine(
                        $"PostgreSQL connection error: " +
                        $"{ex.Message}"
                    );

                    Thread.Sleep(2000);
                }
            }

            Console.WriteLine("Connected to db");

            // Create votes table if it doesn't exist
            var command = connection.CreateCommand();

            command.CommandText = @"
                CREATE TABLE IF NOT EXISTS votes (
                    id VARCHAR(255) NOT NULL UNIQUE,
                    vote VARCHAR(255) NOT NULL
                )
            ";

            command.ExecuteNonQuery();

            command.Dispose();

            return connection;
        }

        // ================================================================
        // Redis connection
        // ================================================================

        private static ConnectionMultiplexer OpenRedisConnection(string hostname)
{
    Console.WriteLine($"Connecting to Redis host: {hostname}");

    while (true)
    {
        try
        {
            var options = ConfigurationOptions.Parse($"{hostname}:6379");

            options.Ssl = true;
            options.AbortOnConnectFail = true;
            options.ConnectRetry = 3;
            options.ConnectTimeout = 10000;
            options.SyncTimeout = 10000;

            Console.WriteLine("Connecting to Redis using TLS...");

            var connection = ConnectionMultiplexer.Connect(options);

            if (connection.IsConnected)
            {
                Console.WriteLine("Connected to redis");
                return connection;
            }

            Console.WriteLine("Redis connection created but IsConnected = false.");

            connection.Dispose();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("REDIS CONNECTION ERROR:");
            Console.Error.WriteLine(ex.ToString());
        }

        Console.WriteLine("Waiting 2 seconds before retrying Redis...");
        Thread.Sleep(2000);
    }
}

        // ================================================================
        // Store vote in PostgreSQL
        // ================================================================

        private static void UpdateVote(
            NpgsqlConnection connection,
            string voterId,
            string vote)
        {
            var command = connection.CreateCommand();

            try
            {
                // Try to insert a new voter
                command.CommandText = @"
                    INSERT INTO votes (id, vote)
                    VALUES (@id, @vote)
                ";

                command.Parameters.AddWithValue(
                    "@id",
                    voterId
                );

                command.Parameters.AddWithValue(
                    "@vote",
                    vote
                );

                command.ExecuteNonQuery();

                Console.WriteLine(
                    $"Vote saved: {vote}"
                );
            }
            catch (DbException)
            {
                /*
                 * The voter already exists.
                 *
                 * Update their existing vote.
                 */

                command.Parameters.Clear();

                command.CommandText = @"
                    UPDATE votes
                    SET vote = @vote
                    WHERE id = @id
                ";

                command.Parameters.AddWithValue(
                    "@id",
                    voterId
                );

                command.Parameters.AddWithValue(
                    "@vote",
                    vote
                );

                command.ExecuteNonQuery();

                Console.WriteLine(
                    $"Vote updated: {vote}"
                );
            }
            finally
            {
                command.Dispose();
            }
        }
    }
}