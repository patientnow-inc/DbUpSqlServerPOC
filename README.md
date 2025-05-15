# DbUp SQL Server POC

This is a minimal proof of concept (POC) demonstrating how to use [DbUp](https://dbup.readthedocs.io/en/latest/) with:
- SQL Server
- Connection string in `appsettings.json`
- PreDeployment, Migration, and PostDeployment SQL scripts

---

## 🚀 Getting Started

### Requirements

- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- SQL Server (local or remote)

---

## ⚙️ Setup

1. Clone this repo or extract the zip.
2. Update `appsettings.json` with your connection string:
   ```json
   {
     "ConnectionStrings": {
       "DefaultConnection": "Server=localhost;Database=MyDb;"
     }
   }