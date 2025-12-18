# Implementation Plan

- [x] 1. Set up project structure and core interfaces






  - [x] 1.1 Create FB::Observability module skeleton

    - Create `lib/FB/Observability.pm` with Moo class structure
    - Define attributes for sentry_dsn, ga4_measurement_id, fb_pixel_id
    - Add placeholder methods for init, capture_error, get_tracking_config
    - _Requirements: 1.1, 1.2, 7.1_
  - [x] 1.2 Create FB::Security module skeleton


    - Create `lib/FB/Security.pm` with Moo class structure
    - Define attributes for rate_limits, rate_limit_max, rate_limit_window
    - Add placeholder methods for check_rate_limit, generate_csrf_token, validate_csrf_token
    - _Requirements: 5.1, 5.2, 5.4_
  - [x] 1.3 Create Ships::Dashboard controller skeleton


    - Create `lib/Ships/Dashboard.pm` extending Mojolicious::Controller
    - Add placeholder methods for index, metrics, logs, health
    - _Requirements: 4.1, 4.3, 8.1_
  - [ ]* 1.4 Set up Test::LectroTest for property-based testing
    - Add Test::LectroTest to cpanfile
    - Create test helper module for common generators
    - _Requirements: Testing infrastructure_


- [x] 2. Implement FB::Observability module




  - [x] 2.1 Implement configuration loading and validation


    - Read SENTRY_DSN, GA4_MEASUREMENT_ID, FB_PIXEL_ID from environment
    - Implement validate_config method with format checking
    - Implement mask_sensitive method for logging
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - [ ]* 2.2 Write property test for configuration validation
    - **Property 13: Configuration Validation**
    - **Validates: Requirements 7.3**
  - [ ]* 2.3 Write property test for sensitive value masking
    - **Property 14: Sensitive Value Masking**
    - **Validates: Requirements 7.4**
  - [ ]* 2.4 Write property test for configuration defaults
    - **Property 12: Configuration Defaults**
    - **Validates: Requirements 7.2**
  - [x] 2.5 Implement Sentry integration


    - Implement init method to initialize Sentry SDK
    - Implement capture_error method with user/request context
    - Handle missing DSN gracefully with warning
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
  - [ ]* 2.6 Write property test for error context completeness
    - **Property 1: Error Context Completeness**
    - **Validates: Requirements 1.4**
  - [ ]* 2.7 Write property test for error data round-trip
    - **Property 2: Error Data Round-Trip**
    - **Validates: Requirements 1.5**
  - [x] 2.8 Implement get_tracking_config for frontend scripts


    - Return hash with ga4_measurement_id and fb_pixel_id
    - Return undef for unconfigured values
    - _Requirements: 2.1, 2.2, 3.1, 3.2_
  - [ ]* 2.9 Write property test for tracking ID preservation
    - **Property 3: Tracking ID Preservation**
    - **Validates: Requirements 2.4, 3.4**


- [x] 3. Checkpoint - Ensure all tests pass




  - Ensure all tests pass, ask the user if questions arise.


- [x] 4. Implement FB::Security module





  - [x] 4.1 Implement security headers

    - Create get_security_headers method returning headers hash
    - Include X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, CSP
    - _Requirements: 5.1_
  - [ ]* 4.2 Write property test for security headers presence
    - **Property 8: Security Headers Presence**
    - **Validates: Requirements 5.1**

  - [x] 4.3 Implement rate limiting

    - Implement check_rate_limit method with IP tracking
    - Track request counts per IP with timestamps
    - Return 0 when limit exceeded, 1 when allowed
    - _Requirements: 5.2, 5.3_


  - [x] 4.4 Implement CSRF token generation and validation
    - Implement generate_csrf_token using secure random
    - Implement validate_csrf_token with timing-safe comparison
    - _Requirements: 5.4_
  - [ ]* 4.5 Write property test for CSRF token validation
    - **Property 9: CSRF Token Validation**
    - **Validates: Requirements 5.4**
  - [x] 4.6 Implement attack pattern detection

    - Create detect_attack_patterns method
    - Check for SQL injection patterns (UNION, SELECT, DROP, etc.)
    - Check for XSS patterns (<script>, javascript:, onerror, etc.)
    - _Requirements: 5.6_
  - [ ]* 4.7 Write property test for attack pattern detection
    - **Property 11: Attack Pattern Detection**
    - **Validates: Requirements 5.6**


- [x] 5. Checkpoint - Ensure all tests pass




  - Ensure all tests pass, ask the user if questions arise.


- [x] 6. Implement Ships::Dashboard controller




  - [x] 6.1 Implement admin authentication middleware


    - Create require_admin method checking user level
    - Return 401 for unauthenticated requests
    - _Requirements: 4.2_
  - [ ]* 6.2 Write property test for dashboard access control
    - **Property 5: Dashboard Access Control**
    - **Validates: Requirements 4.2**

  - [x] 6.3 Implement metrics collection

    - Collect system metrics (uptime, memory, CPU)
    - Collect gaming metrics (users, tables, chips, connections)
    - Collect per-table information
    - _Requirements: 4.1, 4.3, 4.6_
  - [ ]* 6.4 Write property test for dashboard metrics completeness
    - **Property 4: Dashboard Metrics Completeness**
    - **Validates: Requirements 4.1**
  - [ ]* 6.5 Write property test for table info completeness
    - **Property 7: Table Info Completeness**
    - **Validates: Requirements 4.6**
  - [ ]* 6.6 Write property test for dashboard metrics round-trip
    - **Property 6: Dashboard Metrics Round-Trip**
    - **Validates: Requirements 4.5**

  - [x] 6.7 Implement logs endpoint

    - Query recent error logs from storage
    - Support severity filtering
    - Return JSON for API requests
    - _Requirements: 8.1, 8.2, 8.3_
  - [ ]* 6.8 Write property test for log entry completeness
    - **Property 15: Log Entry Completeness**
    - **Validates: Requirements 8.2**
  - [ ]* 6.9 Write property test for log severity filtering
    - **Property 16: Log Severity Filtering**
    - **Validates: Requirements 8.3**
  - [ ]* 6.10 Write property test for log entry round-trip
    - **Property 17: Log Entry Round-Trip**
    - **Validates: Requirements 8.4**

  - [x] 6.11 Implement health check endpoint

    - Return 200 OK with basic status
    - Include database connectivity check
    - _Requirements: 6.4_


- [x] 7. Checkpoint - Ensure all tests pass




  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Integrate modules into Ships.pm





  - [x] 8.1 Add observability initialization to startup


    - Create FB::Observability instance in Ships.pm
    - Initialize Sentry on application start
    - _Requirements: 1.2_
  - [x] 8.2 Add security middleware to routes

    - Apply security headers to all responses
    - Add rate limiting check to route handler
    - _Requirements: 5.1, 5.2_
  - [x] 8.3 Add dashboard routes

    - Add /admin/dashboard route with auth middleware
    - Add /admin/metrics JSON endpoint
    - Add /admin/logs endpoint
    - Add /health endpoint
    - _Requirements: 4.1, 4.2, 6.4_
  - [ ]* 8.4 Write property test for secure cookie flags
    - **Property 10: Secure Cookie Flags**
    - **Validates: Requirements 5.5**


- [x] 9. Update templates for tracking scripts





  - [x] 9.1 Update main.html.ep with GA4 script

    - Add conditional GA4 gtag.js script
    - Pass measurement ID from controller
    - _Requirements: 2.1, 2.2_

  - [ ] 9.2 Update main.html.ep with Facebook Pixel script
    - Add conditional FB Pixel script
    - Pass pixel ID from controller


    - _Requirements: 3.1, 3.2_
  - [x] 9.3 Create admin dashboard template


    - Create templates/admin/dashboard.html.ep




    - Display system metrics, gaming metrics, table list






    - _Requirements: 4.1, 4.3, 4.6_


  - [x] 9.4 Create admin logs template


    - Create templates/admin/logs.html.ep
    - Display log entries with filtering
    - _Requirements: 8.1, 8.2, 8.3_

- [ ] 10. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.


- [x] 11. Update Fly.io deployment configuration






  - [x] 11.1 Update fly.toml with new environment variables

    - Add placeholders for SENTRY_DSN, GA4_MEASUREMENT_ID, FB_PIXEL_ID
    - Update health check to use /health endpoint
    - _Requirements: 6.1, 6.4_

  - [ ] 11.2 Update Dockerfile if needed
    - Ensure all new dependencies are installed

    - _Requirements: 6.1_
  - [ ] 11.3 Update FLY_IO_DEPLOYMENT.md documentation
    - Add section for observability configuration
    - Document new environment variables
    - Add dashboard access instructions
    - _Requirements: 6.1, 6.2, 6.3_

- [x] 12. Update cpanfile with new dependencies





  - Add Sentry::SDK or equivalent Perl Sentry client
  - Add Test::LectroTest for property testing
  - Add any other required modules
  - _Requirements: 1.1, Testing infrastructure_

- [x] 13. Final Checkpoint - Ensure all tests pass





  - Ensure all tests pass, ask the user if questions arise.
