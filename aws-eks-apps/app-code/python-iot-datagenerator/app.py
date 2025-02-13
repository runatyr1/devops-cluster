import os
import time
import json
import random
from datetime import datetime
import boto3
from faker import Faker

# Configure region-specific locations
REGIONS = {
    'us-east-1': {
        'cities': ['New York', 'Boston', 'Washington DC', 'Miami'],
        'routes': ['East Coast Line', 'Atlantic Route', 'Northeast Corridor']
    },
    'us-west-2': {
        'cities': ['Seattle', 'Portland', 'San Francisco', 'Los Angeles'],
        'routes': ['Pacific Route', 'West Coast Line', 'Cascade Corridor']
    }
}

class TrainDataGenerator:
    def __init__(self):
        self.fake = Faker()
        self.region = os.getenv('AWS_REGION', 'us-east-1')
        self.locations = REGIONS[self.region]
        
    def __init__(self):
        self.fake = Faker()
        self.region = os.getenv('AWS_REGION', 'us-east-1')
        self.locations = REGIONS[self.region]
        self.train_counter = 0
        
    def generate_train_data(self):
        self.train_counter += 1
        train_id = f"TRAIN-{self.train_counter:04d}"
        current_city = random.choice(self.locations['cities'])
        route = random.choice(self.locations['routes'])
        
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'train_id': train_id,
            'route': route,
            'current_location': current_city,
            'speed': random.uniform(0, 120),
            'temperature': random.uniform(18, 24),
            'humidity': random.uniform(30, 70),
            'passenger_count': random.randint(0, 500),
            'region': self.region
        }

def main():
    import sys
    generator = TrainDataGenerator()
    
    while True:
        try:
            data = generator.generate_train_data()
            sys.stdout.write(json.dumps(data) + '\n')
            sys.stdout.flush()
            time.sleep(1)
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error generating data: {e}", file=sys.stderr)
            continue

if __name__ == "__main__":
    main()
