using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure JSON options for consistent serialization
builder.Services.Configure<JsonOptions>(options =>
{
    options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
    options.JsonSerializerOptions.WriteIndented = true;
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// OCPI Version Module Endpoints

// GET /versions - Returns list of supported OCPI versions
app.MapGet("/versions", () =>
{
    var response = new
    {
        data = new[]
        {
            new
            {
                version = "2.2.1",
                url = "https://waskito.my.id/versions/2.2.1"
            }
        },
        status_code = 1000,
        status_message = "Success",
        timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    };

    return Results.Ok(response);
})
.WithName("GetVersions")
.WithOpenApi(operation => new(operation)
{
    Summary = "Get supported OCPI versions",
    Description = "Returns a list of supported OCPI versions"
});

// GET /versions/{version_id} - Returns details of a specific version including available modules
app.MapGet("/versions/{version_id}", (string version_id) =>
{
    if (version_id != "2.2.1")
    {
        var notFoundResponse = new
        {
            status_code = 2003,
            status_message = "Unknown version",
            timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        };
        return Results.NotFound(notFoundResponse);
    }

    var response = new
    {
        data = new
        {
            version = "2.2.1",
            endpoints = new[]
            {
                new
                {
                    identifier = "credentials",
                    role = "RECEIVER",
                    url = "https://waskito.my.id/2.2.1/credentials"
                },
                new
                {
                    identifier = "locations",
                    role = "SENDER",
                    url = "https://waskito.my.id/2.2.1/locations"
                },
                new
                {
                    identifier = "sessions",
                    role = "SENDER",
                    url = "https://waskito.my.id/2.2.1/sessions"
                },
                new
                {
                    identifier = "cdrs",
                    role = "SENDER",
                    url = "https://waskito.my.id/2.2.1/cdrs"
                },
                new
                {
                    identifier = "tariffs",
                    role = "SENDER",
                    url = "https://waskito.my.id/2.2.1/tariffs"
                },
                new
                {
                    identifier = "tokens",
                    role = "RECEIVER",
                    url = "https://waskito.my.id/2.2.1/tokens"
                },
                new
                {
                    identifier = "commands",
                    role = "RECEIVER",
                    url = "https://waskito.my.id/2.2.1/commands"
                }
            }
        },
        status_code = 1000,
        status_message = "Success",
        timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    };

    return Results.Ok(response);
})
.WithName("GetVersionDetails")
.WithOpenApi(operation => new(operation)
{
    Summary = "Get version details",
    Description = "Returns details of a specific OCPI version including available modules"
});

// Health check endpoint
app.MapGet("/health", () => new { status = "healthy", timestamp = DateTime.UtcNow })
    .WithName("HealthCheck");

app.Run();