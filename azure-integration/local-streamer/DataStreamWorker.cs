using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace SatisfactoryLocalStreamer;

/// <summary>
/// Background service that manages three independent timers for different data collection frequencies
/// </summary>
public class DataStreamWorker : BackgroundService
{
    private readonly ILogger<DataStreamWorker> _logger;
    private readonly IConfiguration _configuration;
    private readonly SatisfactoryDataStreamer _dataStreamer;
    private readonly int _highFreqInterval;
    private readonly int _mediumFreqInterval;
    private readonly int _standardFreqInterval;
    private readonly int _hourlyFreqInterval;
    private readonly bool _enableHighFreq;
    private readonly bool _enableMediumFreq;
    private readonly bool _enableStandardFreq;
    private readonly bool _enableHourlyFreq;

    public DataStreamWorker(
        ILogger<DataStreamWorker> logger,
        IConfiguration configuration,
        SatisfactoryDataStreamer dataStreamer)
    {
        _logger = logger;
        _configuration = configuration;
        _dataStreamer = dataStreamer;

        // Load interval configurations
        _highFreqInterval = configuration.GetValue<int>("Streaming:HighFrequencyIntervalSeconds", 1);
        _mediumFreqInterval = configuration.GetValue<int>("Streaming:MediumFrequencyIntervalSeconds", 5);
        _standardFreqInterval = configuration.GetValue<int>("Streaming:StandardFrequencyIntervalSeconds", 30);
        _hourlyFreqInterval = configuration.GetValue<int>("Streaming:HourlyFrequencyIntervalSeconds", 3600);

        // Load enable/disable flags
        _enableHighFreq = configuration.GetValue<bool>("Streaming:EnableHighFrequency", true);
        _enableMediumFreq = configuration.GetValue<bool>("Streaming:EnableMediumFrequency", true);
        _enableStandardFreq = configuration.GetValue<bool>("Streaming:EnableStandardFrequency", true);
        _enableHourlyFreq = configuration.GetValue<bool>("Streaming:EnableHourlyFrequency", true);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Satisfactory Data Stream Worker starting...");
        _logger.LogInformation("High Frequency: {Enabled} ({Interval}s)", _enableHighFreq, _highFreqInterval);
        _logger.LogInformation("Medium Frequency: {Enabled} ({Interval}s)", _enableMediumFreq, _mediumFreqInterval);
        _logger.LogInformation("Standard Frequency: {Enabled} ({Interval}s)", _enableStandardFreq, _standardFreqInterval);
        _logger.LogInformation("Hourly Frequency: {Enabled} ({Interval}s)", _enableHourlyFreq, _hourlyFreqInterval);

        // Start all enabled timers concurrently
        var tasks = new List<Task>();

        if (_enableHighFreq)
        {
            tasks.Add(RunHighFrequencyTimer(stoppingToken));
        }

        if (_enableMediumFreq)
        {
            tasks.Add(RunMediumFrequencyTimer(stoppingToken));
        }

        if (_enableStandardFreq)
        {
            tasks.Add(RunStandardFrequencyTimer(stoppingToken));
        }

        if (_enableHourlyFreq)
        {
            tasks.Add(RunHourlyFrequencyTimer(stoppingToken));
        }

        if (tasks.Count == 0)
        {
            _logger.LogWarning("No frequency timers are enabled. Service will not collect any data.");
            return;
        }

        _logger.LogInformation("All enabled timers started. Streaming data to Event Hub...");

        // Wait for all timers to complete (they run until cancellation)
        await Task.WhenAll(tasks);

        _logger.LogInformation("All timers stopped. Worker shutting down.");
    }

    private async Task RunHighFrequencyTimer(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(_highFreqInterval));
        
        _logger.LogInformation("High-frequency timer started (every {Interval}s)", _highFreqInterval);

        try
        {
            // Run immediately on startup
            await _dataStreamer.CollectHighFrequencyData(stoppingToken);

            // Then run on interval
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                await _dataStreamer.CollectHighFrequencyData(stoppingToken);
            }
        }
        catch (OperationCanceledException)
        {
            _logger.LogInformation("High-frequency timer cancelled");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "High-frequency timer failed: {Message}", ex.Message);
            throw;
        }
    }

    private async Task RunMediumFrequencyTimer(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(_mediumFreqInterval));
        
        _logger.LogInformation("Medium-frequency timer started (every {Interval}s)", _mediumFreqInterval);

        try
        {
            // Run immediately on startup
            await _dataStreamer.CollectMediumFrequencyData(stoppingToken);

            // Then run on interval
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                await _dataStreamer.CollectMediumFrequencyData(stoppingToken);
            }
        }
        catch (OperationCanceledException)
        {
            _logger.LogInformation("Medium-frequency timer cancelled");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Medium-frequency timer failed: {Message}", ex.Message);
            throw;
        }
    }

    private async Task RunStandardFrequencyTimer(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(_standardFreqInterval));
        
        _logger.LogInformation("Standard-frequency timer started (every {Interval}s)", _standardFreqInterval);

        try
        {
            // Run immediately on startup
            await _dataStreamer.CollectStandardFrequencyData(stoppingToken);

            // Then run on interval
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                await _dataStreamer.CollectStandardFrequencyData(stoppingToken);
            }
        }
        catch (OperationCanceledException)
        {
            _logger.LogInformation("Standard-frequency timer cancelled");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Standard-frequency timer failed: {Message}", ex.Message);
            throw;
        }
    }

    private async Task RunHourlyFrequencyTimer(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(_hourlyFreqInterval));
        
        _logger.LogInformation("Hourly-frequency timer started (every {Interval}s)", _hourlyFreqInterval);

        try
        {
            // Run immediately on startup
            await _dataStreamer.CollectHourlyFrequencyData(stoppingToken);

            // Then run on interval
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                await _dataStreamer.CollectHourlyFrequencyData(stoppingToken);
            }
        }
        catch (OperationCanceledException)
        {
            _logger.LogInformation("Hourly-frequency timer cancelled");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Hourly-frequency timer failed: {Message}", ex.Message);
            throw;
        }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Satisfactory Data Stream Worker stopping...");
        await base.StopAsync(cancellationToken);
        _logger.LogInformation("Worker stopped successfully");
    }
}
