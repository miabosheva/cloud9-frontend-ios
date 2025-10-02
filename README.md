# Cloud9 – Sleep Management & Optimization System

**Cloud9** is a comprehensive sleep management system designed to track, analyze, and optimize sleep patterns. The system consists of an iOS application and a watchOS application, synchronized through Apple HealthKit and a Firebase backend.

---

## Table of Contents
1. [Overview](#overview)  
2. [Features](#features)  
3. [Architecture](#architecture)  
4. [Installation](#installation)  

---

## Overview
Cloud9 enables users to:
- Track sleep manually or via Apple Watch sensors.  
- Calculate sleep debt and receive personalized recommendations.  
- Visualize sleep patterns through interactive charts.  
- Sync sleep logs across iOS and watchOS devices using HealthKit and Firebase.  

The system is built using Swift and SwiftUI for iOS/watchOS, with Firebase as a serverless backend for authentication, storage, and analytics.

---

## Features
| Feature | iOS App | watchOS App | Planned / Future |
|---------|---------|-------------|----------------|
| Sleep Tracking | ✅ | ❌ | – |
| Automatic Sleep Detection | ❌ | ✅ | – |
| Heart Rate Monitoring | ✅ | ✅ | – |
| Sleep Debt Calculation | ✅ | ❌ | – |
| AI-Based Insights | ✅ | ❌ | – |
| Data Visualization | ✅ | ✅ | – |
| Notifications | ❌ | ❌ | ✅ |
| Sign In with Apple | ❌ | ❌ | ✅ |

---

## Architecture
Cloud9 uses a multi-tier architecture:  
1. **iOS App** – Primary UI, data visualization, state management via MVVM.  
2. **watchOS App** – Sleep tracking interface, heart rate monitoring, local data buffering.  
3. **Firebase Backend** – Firestore for data storage, Authentication for login, Cloud Functions for analytics, and optional Cloud Messaging for notifications.  

## Installation
1. Clone the repository:  
   ```bash
   git clone https://github.com/yourusername/cloud9.git
