# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application for gait analysis experiments that connects to M5Stack devices via Bluetooth. The app is designed to:
- Collect accelerometer data from BLE devices
- Conduct walking experiments with metronome guidance
- Analyze gait patterns in real-time
- Upload experiment data to Azure Blob Storage

## Key Commands

### Development
```bash
# Run the app
flutter run

# Run on specific device
flutter run -d <device_id>

# Build for iOS
flutter build ios

# Install dependencies
flutter pub get

# Clean build artifacts
flutter clean
```

### Code Quality
```bash
# Run static analysis
flutter analyze

# Format code
dart format lib/
```

## Architecture

### Core Services
- **BLE Service** (`lib/services/ble_service.dart`): Handles Bluetooth communication with M5Stack devices
- **Experiment Controller** (`lib/services/experiment_controller.dart`): Manages experiment phases and data collection
- **Metronome Services**: Two implementations - Flutter-based (`metronome.dart`) and native iOS (`native_metronome.dart`)
- **Background Service**: Handles background data collection and notifications
- **Data Upload Service**: Manages Azure Blob Storage uploads

### Experiment Flow
1. **Preparation Phase** (5 min): Initial setup and calibration
2. **Baseline Phase** (5 min): Free walking to establish baseline
3. **Adaptation Phase** (2 min): Introduction to metronome rhythm
4. **Induction Phase** (10 min): Guided walking with varying BPM
5. **Post-Effect Phase** (5 min): Free walking to measure retention
6. **Evaluation Phase** (2 min): User feedback collection

### Data Models
- **SensorData**: Accelerometer readings from M5Stack
- **ExperimentSession**: Complete experiment metadata and results
- **ExperimentRecord**: Individual data points during experiments

## Current Design Considerations

The app is currently optimized for iPhone with:
- Fixed padding values (16px standard)
- Fixed widget sizes (e.g., SizedBox width: 160, height: 50)
- No responsive layout patterns
- Portrait orientation assumed

## Environment Setup

The app requires a `.env` file with Azure credentials:
```
AZURE_STORAGE_ACCOUNT=<account_name>
AZURE_SAS_TOKEN=<sas_token>
AZURE_CONTAINER_NAME=<container_name>
```

## Platform-Specific Notes

### iOS
- Native metronome implementation in Swift (`NativeMetronomePlugin.swift`)
- Requires CoreBluetooth permissions
- Background modes configured for audio and Bluetooth

### Android
- Standard Flutter metronome implementation
- Requires Bluetooth and location permissions