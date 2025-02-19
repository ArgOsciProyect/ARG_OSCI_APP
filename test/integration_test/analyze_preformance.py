# analyze_performance.py
import subprocess
import pandas as pd
import re
import os
from datetime import datetime

def run_test(n):
    """Run the Flutter test and return the log filename"""
    print(f"Running test iteration {n+1}/1000...")
    subprocess.run(["flutter", "test", "/home/jotalora/Tesis/ARG_OSCI_APP/test/integration_test/data_processing_profilling_test.dart", "--no-pub"], 
                  capture_output=True)
    return f"/home/jotalora/Tesis/ARG_OSCI_APP/log/data_processing_performance_python.log"

def parse_log(filename):
    """Parse the log file and extract performance metrics"""
    with open(filename, 'r') as f:
        content = f.read()

    # Split into test cases
    test_cases = re.split(r'=== Test Case:', content)
    
    results = []
    for case in test_cases[1:]:  # Skip first empty split
        # Extract basic info
        test_name = re.search(r'(.*?)===', case).group(1).strip()
        operation = re.search(r'Operation: (.*?)\n', case).group(1).strip()
        data_size = int(re.search(r'Data Size: (\d+) points', case).group(1))
        duration_us = int(re.search(r'Duration: (\d+)µs', case).group(1))
        
        # Extract performance metrics
        metrics = {}
        metrics_section = re.search(r'Performance Metrics:\n(.*?)\n=', case, re.DOTALL)
        if metrics_section:
            for line in metrics_section.group(1).split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    metrics[key.strip()] = float(value.strip())
        
        results.append({
            'test_name': test_name,
            'operation': operation,
            'data_size': data_size,
            'duration_us': duration_us,
            **metrics
        })
    
    return pd.DataFrame(results)

def analyze_results(all_results, iteration):
    """Analyze results and save to file"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"/home/jotalora/Tesis/ARG_OSCI_APP/test/integration_test/performance_analysis_{iteration}_{timestamp}.txt"
    
    with open(output_file, 'w') as f:
        f.write(f"Performance Analysis - Iteration {iteration}\n")
        f.write("=" * 80 + "\n\n")

        # Group by test name and operation
        grouped = all_results.groupby(['test_name', 'operation'])
        
        for (test, op), data in grouped:
            f.write(f"Test: {test}\n")
            f.write(f"Operation: {op}\n")
            f.write("-" * 40 + "\n")
            
            # Basic statistics
            f.write("\nTiming Statistics (microseconds):\n")
            f.write(f"Mean duration: {data['duration_us'].mean():.2f}\n")
            f.write(f"Std deviation: {data['duration_us'].std():.2f}\n")
            f.write(f"Min duration: {data['duration_us'].min():.2f}\n")
            f.write(f"Max duration: {data['duration_us'].max():.2f}\n")
            
            # Performance metrics statistics
            metrics_cols = [col for col in data.columns 
                          if col not in ['test_name', 'operation', 'data_size', 'duration_us']]
            
            if metrics_cols:
                f.write("\nPerformance Metrics Statistics:\n")
                for metric in metrics_cols:
                    f.write(f"\n{metric}:\n")
                    f.write(f"  Mean: {data[metric].mean():.6f}\n")
                    f.write(f"  Std:  {data[metric].std():.6f}\n")
                    f.write(f"  Min:  {data[metric].min():.6f}\n")
                    f.write(f"  Max:  {data[metric].max():.6f}\n")
            
            f.write("\n" + "=" * 80 + "\n\n")

def main():
    # Create log directory if it doesn't exist
    os.makedirs("log", exist_ok=True)
    
    all_results = []
    
    for i in range(100):
        log_file = run_test(i)
        results = parse_log(log_file)
        all_results.append(results)
        
        # Analyze accumulated results every 10 iterations
        if (i + 1) % 100 == 0:
            combined_results = pd.concat(all_results)
            analyze_results(combined_results, i + 1)
            
    # Final analysis
    final_results = pd.concat(all_results)
    analyze_results(final_results, 100)

if __name__ == "__main__":
    main()