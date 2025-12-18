# Requirements Document

## Introduction

This document specifies requirements for adding comprehensive observability, analytics, and monitoring capabilities to the MojoPoker application, along with server hardening measures and updated deployment documentation. The feature set includes integration with Sentry for error tracking, Google Analytics 4 (GA4) for user analytics, Facebook Pixel for conversion tracking, an admin dashboard for real-time gaming metrics, Mojolicious server hardening, and updated Fly.io deployment procedures.

## Glossary

- **MojoPoker_System**: The Perl-based Mojolicious poker application including backend services and frontend UI
- **Sentry**: A third-party error monitoring and performance tracking service
- **GA4**: Google Analytics 4, a web analytics platform for tracking user behavior
- **Facebook_Pixel**: A JavaScript snippet for tracking user actions and conversions for Facebook advertising
- **Admin_Dashboard**: A protected web interface displaying real-time gaming and system metrics
- **Observability_Module**: A Perl module responsible for collecting and reporting metrics
- **Rate_Limiter**: A component that restricts the number of requests from a single source
- **CSRF_Token**: Cross-Site Request Forgery protection token
- **CSP**: Content Security Policy, HTTP headers that restrict resource loading
- **Fly_Deployment**: The process of deploying the application to Fly.io infrastructure

## Requirements

### Requirement 1

**User Story:** As a system administrator, I want to track application errors in Sentry, so that I can identify and fix issues before they impact users.

#### Acceptance Criteria

1. WHEN the MojoPoker_System encounters an uncaught exception THEN the Observability_Module SHALL capture the error details and send them to Sentry within 5 seconds
2. WHEN the MojoPoker_System starts THEN the Observability_Module SHALL initialize Sentry with the configured DSN from environment variables
3. WHEN Sentry DSN environment variable is not configured THEN the Observability_Module SHALL log a warning and continue operation without Sentry integration
4. WHEN an error is captured THEN the Observability_Module SHALL include user context (user_id, login_id) and request context (URL, method) in the Sentry event
5. WHEN serializing error data for Sentry THEN the Observability_Module SHALL produce valid JSON that round-trips correctly through encode and decode operations

### Requirement 2

**User Story:** As a product manager, I want to track user behavior with GA4, so that I can understand how players interact with the poker application.

#### Acceptance Criteria

1. WHEN a user loads the main page THEN the MojoPoker_System SHALL include the GA4 tracking script with the configured measurement ID
2. WHEN GA4 measurement ID environment variable is not configured THEN the MojoPoker_System SHALL omit the GA4 tracking script from the page
3. WHEN a user performs a trackable action (login, join_table, place_bet, win_hand) THEN the frontend SHALL send a custom event to GA4
4. WHEN rendering the GA4 script THEN the MojoPoker_System SHALL use the measurement ID exactly as configured without modification

### Requirement 3

**User Story:** As a marketing manager, I want to track conversions with Facebook Pixel, so that I can measure advertising effectiveness.

#### Acceptance Criteria

1. WHEN a user loads the main page THEN the MojoPoker_System SHALL include the Facebook Pixel script with the configured pixel ID
2. WHEN Facebook Pixel ID environment variable is not configured THEN the MojoPoker_System SHALL omit the Facebook Pixel script from the page
3. WHEN a user completes a conversion action (registration, chip_purchase) THEN the frontend SHALL fire the appropriate Facebook Pixel event
4. WHEN rendering the Facebook Pixel script THEN the MojoPoker_System SHALL use the pixel ID exactly as configured without modification

### Requirement 4

**User Story:** As a system administrator, I want an admin dashboard showing gaming metrics, so that I can monitor system health and player activity in real-time.

#### Acceptance Criteria

1. WHEN an authenticated admin user requests the dashboard endpoint THEN the Admin_Dashboard SHALL display current active users count, active tables count, and total chips in play
2. WHEN an unauthenticated user requests the dashboard endpoint THEN the MojoPoker_System SHALL return HTTP 401 status and deny access
3. WHEN the dashboard is requested THEN the Admin_Dashboard SHALL display system uptime, memory usage, and WebSocket connection count
4. WHEN the dashboard data is requested THEN the Admin_Dashboard SHALL return the response within 2 seconds
5. WHEN serializing dashboard metrics THEN the Admin_Dashboard SHALL produce valid JSON that round-trips correctly through encode and decode operations
6. WHEN displaying table information THEN the Admin_Dashboard SHALL show table ID, game type, player count, and pot size for each active table

### Requirement 5

**User Story:** As a security engineer, I want the Mojolicious server hardened against common attacks, so that the application is protected from malicious actors.

#### Acceptance Criteria

1. WHEN the MojoPoker_System receives a request THEN the server SHALL include security headers (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Content-Security-Policy)
2. WHEN a single IP address exceeds 100 requests per minute THEN the Rate_Limiter SHALL return HTTP 429 status for subsequent requests
3. WHEN the rate limit is applied THEN the Rate_Limiter SHALL reset the counter after 60 seconds
4. WHEN a form is submitted THEN the MojoPoker_System SHALL validate the CSRF_Token before processing
5. WHEN session cookies are set THEN the MojoPoker_System SHALL mark them as HttpOnly and Secure
6. WHEN the MojoPoker_System receives a request with suspicious patterns (SQL injection, XSS attempts) THEN the server SHALL log the attempt and reject the request

### Requirement 6

**User Story:** As a DevOps engineer, I want updated deployment documentation for Fly.io, so that I can deploy the application reliably with all new features.

#### Acceptance Criteria

1. WHEN deploying to Fly.io THEN the deployment process SHALL configure all required environment variables for Sentry, GA4, and Facebook Pixel
2. WHEN the Fly.io deployment completes THEN the MojoPoker_System SHALL be accessible via HTTPS with valid SSL certificate
3. WHEN the deployment documentation is followed THEN the deployment process SHALL complete without manual intervention beyond initial secret configuration
4. WHEN health checks are configured THEN Fly.io SHALL verify the application responds to HTTP requests on the configured port

### Requirement 7

**User Story:** As a developer, I want observability configuration to be centralized, so that I can easily manage tracking settings across environments.

#### Acceptance Criteria

1. WHEN the MojoPoker_System starts THEN the Observability_Module SHALL read configuration from environment variables (SENTRY_DSN, GA4_MEASUREMENT_ID, FB_PIXEL_ID)
2. WHEN environment variables are missing THEN the Observability_Module SHALL use safe defaults that disable the respective tracking feature
3. WHEN configuration is loaded THEN the Observability_Module SHALL validate that configured values match expected formats
4. WHEN serializing configuration for logging THEN the Observability_Module SHALL mask sensitive values (show only last 4 characters of DSN/IDs)

### Requirement 8

**User Story:** As a system administrator, I want to view error logs and metrics history, so that I can troubleshoot issues and track trends over time.

#### Acceptance Criteria

1. WHEN an admin requests the dashboard logs endpoint THEN the Admin_Dashboard SHALL display the most recent 100 error log entries
2. WHEN displaying log entries THEN the Admin_Dashboard SHALL show timestamp, severity level, message, and source location
3. WHEN filtering logs by severity THEN the Admin_Dashboard SHALL return only entries matching the specified level
4. WHEN log entries are serialized THEN the Admin_Dashboard SHALL produce valid JSON that round-trips correctly through encode and decode operations
