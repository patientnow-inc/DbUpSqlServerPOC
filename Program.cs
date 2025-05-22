using System;
using System.IO;
using System.Linq;
using System.Reflection;
using Microsoft.Extensions.Configuration;
using DbUp;
using DbUp.Engine;
using DbUp.Helpers;
using System.Collections.Generic;
using DbUpSqlServerPOC;
using System.Text.Json;
using System.Threading.Tasks;

class Program
{
    static async Task<int> Main(string[] args)
    {
        Console.WriteLine("Working Directory: " + Directory.GetCurrentDirectory());

        var environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Development";

        var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json")
            .AddJsonFile($"appsettings.{environment}.json", optional: true)
            .AddEnvironmentVariables();

        var config = builder.Build();

        var secretName = config["AWS:SecretsManagerSecretName"];
        var region = config["AWS:Region"];

        if (string.IsNullOrEmpty(secretName))
        {
            Console.WriteLine("AWS SecretsManagerSecretName is not configured.");
            return 1;
        }

        if (string.IsNullOrEmpty(region))
        {
            region = "us-east-1"; // default region if not set
        }

        var awsSecretsHelper = new AwsSecretsManagerHelper();

        string secretJson = await awsSecretsHelper.GetSecretAsync(secretName, region);

        var secretData = JsonSerializer.Deserialize<Dictionary<string, string>>(secretJson);

      //  string connectionString = secretData["DefaultConnection"];       

        var connectionString = config.GetConnectionString("DefaultConnection");

        Console.WriteLine($"Running in Environment: {environment}");
        Console.WriteLine("ConnectionString: " + connectionString);

        Console.WriteLine("Running PreDeployment Scripts...");
        ExecuteScripts("Scripts/PreDeployment", connectionString, nonJournaled: true);

        var appliedScripts = new List<string>();

        Console.WriteLine("Running Migration Scripts...");
        var upgrader = DeployChanges.To
            .SqlDatabase(connectionString)
            .WithScriptsEmbeddedInAssembly(
                Assembly.GetExecutingAssembly(),
                s =>
                {
                    bool match = s.StartsWith("DbUpSqlServerPOC.Scripts.Migrations");
                    if (match) appliedScripts.Add(Path.GetFileName(s));
                    return match;
                })
            .JournalToSqlTable("dbo", "SchemaVersions")
            .LogToConsole()
            .Build();

        var result = upgrader.PerformUpgrade();

        if (!result.Successful)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("Migration failed: " + result.Error);
            Console.ResetColor();

            Console.WriteLine("Rolling back applied migration scripts...");
            RunRollbackScripts("Scripts/Rollback", connectionString, appliedScripts);

            return -1;
        }

        Console.WriteLine("Running PostDeployment Scripts...");
        ExecuteScripts("Scripts/PostDeployment", connectionString, nonJournaled: true);

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("Success!");
        Console.ResetColor();
        return 0;
    }

    static void ExecuteScripts(string path, string connectionString, bool nonJournaled)
    {
        if (!Directory.Exists(path))
        {
            Console.WriteLine($"Directory not found: {path}");
            return;
        }

        var scripts = Directory.GetFiles(path, "*.sql").OrderBy(x => x).ToArray();

        foreach (var script in scripts)
        {
            var sqlScript = new SqlScript(Path.GetFileName(script), File.ReadAllText(script));

            var builder = DeployChanges.To
                .SqlDatabase(connectionString)
                .WithScripts(new[] { sqlScript })
                .LogToConsole();

            if (nonJournaled)
            {
                builder = builder.JournalTo(new NullJournal());
            }

            var upgrader = builder.Build();
            var result = upgrader.PerformUpgrade();

            if (!result.Successful)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"Error running {script}: {result.Error}");
                Console.ResetColor();
                Environment.Exit(-1);
            }
        }
    }

    static void RunRollbackScripts(string rollbackPath, string connectionString, List<string> appliedScripts)
    {
        if (!Directory.Exists(rollbackPath))
        {
            Console.WriteLine($"Rollback folder not found: {rollbackPath}");
            return;
        }

        foreach (var applied in appliedScripts.AsEnumerable().Reverse())
        {
            var rollbackFile = Directory.GetFiles(rollbackPath, $"{Path.GetFileNameWithoutExtension(applied)}-rollback.sql").FirstOrDefault();
            if (rollbackFile != null)
            {
                Console.WriteLine($"Rolling back: {rollbackFile}");
                ExecuteScripts(Path.GetDirectoryName(rollbackFile), connectionString, nonJournaled: true);
            }
        }
    }
}