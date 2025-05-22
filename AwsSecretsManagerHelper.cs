using Amazon.SecretsManager;
using Amazon.SecretsManager.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DbUpSqlServerPOC
{
    class AwsSecretsManagerHelper
    {
        private readonly IAmazonSecretsManager _client;

        public AwsSecretsManagerHelper()
        {
            _client = new AmazonSecretsManagerClient(); // Uses default credentials from environment, IAM role, etc.
        }

        public async Task<string> GetSecretAsync(string secretName, string region = "us-east-1")
        {
            var request = new GetSecretValueRequest
            {
                SecretId = secretName
            };

            try
            {
                var response = await _client.GetSecretValueAsync(request);
                if (response.SecretString != null)
                    return response.SecretString;
                else
                    throw new Exception("Secret binary data is not supported");
            }
            catch (Exception ex)
            {
                throw new Exception($"Error retrieving secret {secretName}: {ex.Message}", ex);
            }
        }
    }
}
