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
                // Read database and Redis hosts from ECS environment variables
                var postgresHost = Environment.GetEnvironmentVariable("POSTGRES_HOST");
                var redisHost = Environment.GetEnvironmentVariable("REDIS_HOST");

                Console.WriteLine($"POSTGRES_HOST: {postgresHost}");
                Console.WriteLine($"REDIS_HOST: {redisHost}");

                // Connect to PostgreSQL
                var pgsql = OpenDbConnection(
                    $"Server={postgresHost};Username=postgres;Password=postgres;"
                );

                // Connect to Redis
                var redisConn = OpenRedisConnection(redisHost);
                var redis = redisConn.GetDatabase();

                // Keep-alive command for PostgreSQL
                var keepAliveCommand = pgsql.CreateCommand();
                keepAliveCommand.CommandText = "SELECT 1";

                var definition = new { vote = "", voter_id = "" };

                while (true)
                {
                    // Slow down to prevent CPU spike
                    Thread.Sleep(100);

                    // Reconnect Redis if connection is lost
                    if (redisConn == null || !redisConn.IsConnected)
                    {
                        Console.WriteLine("Reconnecting Redis");

                        redisConn = OpenRedisConnection(redisHost);
                        redis = redisConn.GetDatabase();
                    }

                    // Get vote from Redis
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
                        if (!pgsql.State.Equals(System.Data.ConnectionState.Open))
                        {
                            Console.WriteLine("Reconnecting DB");

                            pgsql = OpenDbConnection(
                                $"Server={postgresHost};Username=postgres;Password=postgres;"
                            );
                        }
                        else
                        {
                            // Process the vote
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
            string connectionString
        )
        {
            NpgsqlConnection connection;

            while (true)
            {
                try
                {
                    connection = new NpgsqlConnection(connectionString);
                    connection.Open();

                    break;
                }
                catch (SocketException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
                catch (DbException)
                {
                    Console.Error.WriteLine("Waiting for db");
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

            return connection;
        }

        private static ConnectionMultiplexer OpenRedisConnection(
            string hostname
        )
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
                    a => a.AddressFamily == AddressFamily.InterNetwork
                )
                .ToString();
        }

        private static void UpdateVote(
            NpgsqlConnection connection,
            string voterId,
            string vote
        )
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
                // Voter already exists → update their vote
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