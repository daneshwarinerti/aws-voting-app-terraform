using System;
using System.Data.Common;
using System.Linq;
using System.Net;
using System.Net.Sockets;
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
                // Read connection details from environment variables
                var postgresHost = Environment.GetEnvironmentVariable("POSTGRES_HOST");
                var postgresUser = Environment.GetEnvironmentVariable("POSTGRES_USER");
                var postgresPassword = Environment.GetEnvironmentVariable("POSTGRES_PASSWORD");

                var redisHost = Environment.GetEnvironmentVariable("REDIS_HOST");

                Console.WriteLine($"POSTGRES_HOST: {postgresHost}");
                Console.WriteLine($"POSTGRES_USER: {postgresUser}");
                Console.WriteLine($"REDIS_HOST: {redisHost}");

                if (string.IsNullOrEmpty(postgresHost) ||
                    string.IsNullOrEmpty(postgresUser) ||
                    string.IsNullOrEmpty(postgresPassword))
                {
                    Console.Error.WriteLine("PostgreSQL environment variables are missing.");
                    return 1;
                }

                if (string.IsNullOrEmpty(redisHost))
                {
                    Console.Error.WriteLine("REDIS_HOST environment variable is missing.");
                    return 1;
                }

                // Connect to PostgreSQL
                var pgsql = OpenDbConnection(
                    postgresHost,
                    postgresUser,
                    postgresPassword
                );

                // Connect to Redis
                var redisConn = OpenRedisConnection(redisHost);
                var redis = redisConn.GetDatabase();

                // PostgreSQL keep-alive command
                var keepAliveCommand = pgsql.CreateCommand();
                keepAliveCommand.CommandText = "SELECT 1";

                var definition = new { vote = "", voter_id = "" };

                while (true)
                {
                    // Prevent excessive CPU usage
                    Thread.Sleep(100);

                    // Reconnect Redis if connection is lost
                    if (redisConn == null || !redisConn.IsConnected)
                    {
                        Console.WriteLine("Reconnecting Redis");

                        redisConn = OpenRedisConnection(redisHost);
                        redis = redisConn.GetDatabase();
                    }

                    // Get a vote from Redis
                    string json = redis.ListLeftPopAsync("votes").Result;

                    if (json != null)
                    {
                        var vote = JsonConvert.DeserializeAnonymousType(
                            json,
                            definition
                        );

                        Console.WriteLine(
                            $"Processing vote for '{vote.vote}' by '{vote.voter_id}'"
                        );

                        // Reconnect PostgreSQL if connection is lost
                        if (!pgsql.State.Equals(
                            System.Data.ConnectionState.Open))
                        {
                            Console.WriteLine("Reconnecting DB");

                            pgsql = OpenDbConnection(
                                postgresHost,
                                postgresUser,
                                postgresPassword
                            );
                        }
                        else
                        {
                            // Store the vote in PostgreSQL
                            UpdateVote(
                                pgsql,
                                vote.voter_id,
                                vote.vote
                            );
                        }
                    }
                    else
                    {
                        // Keep PostgreSQL connection alive
                        keepAliveCommand.ExecuteNonQuery();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 1;
            }
        }

        private static NpgsqlConnection OpenDbConnection(
            string host,
            string username,
            string password)
        {
            NpgsqlConnection connection;

            string connectionString =
                $"Server={host};Database=voting;Username={username};Password={password};Ssl Mode=Require;";

            while (true)
            {
                try
                {
                    connection = new NpgsqlConnection(connectionString);

                    connection.Open();

                    break;
                }
                catch (SocketException ex)
               {
                   Console.Error.WriteLine($"Network error connecting to PostgreSQL: {ex.Message}");
                   Thread.Sleep(1000);
                }
                catch (DbException ex)
                {
                    Console.Error.WriteLine($"PostgreSQL connection error: {ex.Message}");
                    Thread.Sleep(1000);
                }
            }

            Console.Error.WriteLine("Connected to db");

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

        private static ConnectionMultiplexer OpenRedisConnection(
            string hostname)
        {
            // Resolve Redis hostname to IPv4 address
            var ipAddress = GetIp(hostname);

            Console.WriteLine($"Found redis at {ipAddress}");

            while (true)
            {
                try
                {
                    Console.Error.WriteLine("Connecting to redis");

                    return ConnectionMultiplexer.Connect(ipAddress);
                }
                catch (RedisConnectionException)
                {
                    Console.Error.WriteLine("Waiting for redis");
                    Thread.Sleep(1000);
                }
            }
        }

        private static string GetIp(string hostname)
        {
            return Dns.GetHostEntryAsync(hostname)
                .Result
                .AddressList
                .First(
                    a => a.AddressFamily ==
                         AddressFamily.InterNetwork
                )
                .ToString();
        }

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

                command.Parameters.AddWithValue("@id", voterId);
                command.Parameters.AddWithValue("@vote", vote);

                command.ExecuteNonQuery();
            }
            catch (DbException)
            {
                // Voter already exists, so update the vote
                command.CommandText = @"
                    UPDATE votes
                    SET vote = @vote
                    WHERE id = @id
                ";

                command.ExecuteNonQuery();
            }
            finally
            {
                command.Dispose();
            }
        }
    }
}