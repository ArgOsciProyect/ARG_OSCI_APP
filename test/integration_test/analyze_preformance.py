# analyze_performance.py
import subprocess
import pandas as pd
import re
import os
from datetime import datetime
import shutil

BASE_PATH = "/home/jotalora/Tesis/ARG_OSCI_APP"
LOG_DIR = f"{BASE_PATH}/test/integration_test/logs"
RESULTS_DIR = f"{BASE_PATH}/test/integration_test/results"

def setup_directories():
    """Setup log and results directories"""
    for directory in [LOG_DIR, RESULTS_DIR]:
        if os.path.exists(directory):
            shutil.rmtree(directory)
        os.makedirs(directory)

def run_test(n):
    """Run the Flutter test and return the log filename"""
    log_file = f"{LOG_DIR}/osci_test_performance_{n}.log"
    
    # Update LOG_FILE_PATH in the test file
    test_file = f"{BASE_PATH}/test/integration_test/data_processing_profilling_test.dart"
    with open(test_file, 'r') as f:
        content = f.read()
    
    modified_content = re.sub(
        r'const String LOG_FILE_PATH = .*',
        f"const String LOG_FILE_PATH = '{log_file}';",
        content
    )
    
    with open(test_file, 'w') as f:
        f.write(modified_content)

    print(f"Running test iteration {n+1}/100...")
    result = subprocess.run(
        ["flutter", "test", test_file, "--no-pub"],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"Test failed: {result.stderr}")
        return None
        
    return log_file if os.path.exists(log_file) else None

def parse_log(filename):
    """Parse the log file and extract performance metrics"""
    if not filename or not os.path.exists(filename):
        return pd.DataFrame()
        
    with open(filename, 'r') as f:
        content = f.read()

    test_cases = re.split(r'=== Test Case:', content)
    results = []
    
    for case in test_cases[1:]:
        try:
            test_name = re.search(r'(.*?)===', case).group(1).strip()
            operation = re.search(r'Operation: (.*?)\n', case).group(1).strip()
            data_size = int(re.search(r'Data Size: (\d+) points', case).group(1))
            duration_us = int(re.search(r'Duration: (\d+)µs', case).group(1))
            
            metrics = {}
            metrics_section = re.search(r'Performance Metrics:\n(.*?)\n=', case, re.DOTALL)
            if metrics_section:
                for line in metrics_section.group(1).split('\n'):
                    if ':' in line:
                        key, value = line.split(':', 1)
                        try:
                            metrics[key.strip()] = float(value.strip())
                        except ValueError:
                            continue
            
            results.append({
                'iteration': os.path.basename(filename).split('_')[-1].split('.')[0],
                'test_name': test_name,
                'operation': operation,
                'data_size': data_size,
                'duration_us': duration_us,
                **metrics
            })
        except Exception as e:
            print(f"Error parsing test case: {e}")
            continue
    
    return pd.DataFrame(results)

def analyze_results(df):
    """Generate comprehensive analysis report"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"{RESULTS_DIR}/performance_analysis_{timestamp}.txt"
    
    with open(output_file, 'w') as f:
        f.write("Performance Analysis Report\n")
        f.write("=" * 80 + "\n\n")
        
        # Group by test name and operation
        grouped = df.groupby(['test_name', 'operation'])
        
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
            f.write(f"95th percentile: {data['duration_us'].quantile(0.95):.2f}\n")
            
            # Performance metrics statistics
            metrics_cols = [col for col in data.columns 
                          if col not in ['iteration', 'test_name', 'operation', 'data_size', 'duration_us']]
            
            if metrics_cols:
                f.write("\nPerformance Metrics Statistics:\n")
                for metric in metrics_cols:
                    f.write(f"\n{metric}:\n")
                    f.write(f"  Mean: {data[metric].mean():.6f}\n")
                    f.write(f"  Std:  {data[metric].std():.6f}\n")
                    f.write(f"  Min:  {data[metric].min():.6f}\n")
                    f.write(f"  Max:  {data[metric].max():.6f}\n")
                    f.write(f"  95th: {data[metric].quantile(0.95):.6f}\n")
            
            f.write("\n" + "=" * 80 + "\n\n")
        
        # Save raw data
        csv_file = f"{RESULTS_DIR}/raw_results_{timestamp}.csv"
        df.to_csv(csv_file, index=False)
        f.write(f"\nRaw data saved to: {csv_file}\n")

def main():
    setup_directories()
    all_results = []
    
    for i in range(100):
        log_file = run_test(i)
        if log_file:
            results = parse_log(log_file)
            if not results.empty:
                all_results.append(results)
    
    if all_results:
        final_results = pd.concat(all_results, ignore_index=True)
        analyze_results(final_results)
        print(f"\nAnalysis complete. Results saved in {RESULTS_DIR}")
    else:
        print("No valid results to analyze")

if __name__ == "__main__":
    main()