# Cloud9 – Sleep Management & Optimization System

**Cloud9** is a comprehensive sleep management solution designed to help you understand and improve your sleep quality. Built for iOS and Apple Watch, it seamlessly tracks your sleep patterns, provides personalized insights, and helps you maintain healthy sleep habits through intelligent analysis and recommendations.

---

## Table of Contents
1. [Overview](#overview)  
2. [Features](#features)  
3. [Architecture](#architecture)  
4. [Installation](#installation)

---

## Overview

Cloud9 empowers you to take control of your sleep health by:

- **Tracking your sleep** – Record sleep sessions manually or automatically through Apple Watch sensors
- **Understanding your patterns** – Calculate sleep debt and receive tailored recommendations based on your unique sleep needs
- **Visualizing your progress** – View detailed sleep analytics through intuitive, interactive charts
- **Staying synchronized** – Seamlessly sync your sleep data across all your devices using Apple HealthKit and Firebase

Built with modern Swift and SwiftUI technologies, Cloud9 leverages Firebase as a robust serverless backend to provide authentication, cloud storage, and real-time analytics across your devices.

---

## Features

The following table outlines current capabilities and planned enhancements:

| Feature | iOS App | watchOS App | Coming Soon |
|---------|---------|-------------|-------------|
| Manual Sleep Tracking | Yes | No | – |
| Automatic Sleep Detection | No | Yes | – |
| Heart Rate Monitoring | Yes | Yes | – |
| Sleep Debt Calculation | Yes | No | – |
| AI-Powered Sleep Insights | Yes | No | – |
| Interactive Data Visualization | Yes | Yes | – |
| Smart Notifications | No | No | Planned |
| Sign In with Apple | No | No | Planned |

---

## Architecture

Cloud9 is built on a modern, scalable multi-tier architecture:

**iOS Application** – Serves as the primary interface with rich data visualizations and follows the MVVM (Model-View-ViewModel) pattern for clean, maintainable code structure

**watchOS Application** – Provides convenient sleep tracking directly from your wrist, monitors heart rate metrics, and buffers data locally for reliable syncing

**Firebase Backend** – Powers the entire ecosystem with Firestore for cloud data storage, Firebase Authentication for secure user management, Cloud Functions for advanced analytics processing, and optional Cloud Messaging for push notifications

---

## Installation

Getting started with Cloud9 is straightforward:

1. Clone the repository:  
```bash
   git clone https://github.com/yourusername/cloud9.git
