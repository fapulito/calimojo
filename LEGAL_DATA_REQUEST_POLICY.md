# Public Authority Data Request Policy

**Effective Date:** December 16, 2024  
**Last Updated:** December 16, 2024  
**Version:** 1.0

---

## 1. Purpose

This policy establishes procedures for handling requests from public authorities (law enforcement, government agencies, courts) for personal data or personal information of Mojo Poker users. It ensures compliance with applicable laws while protecting user privacy rights.

---

## 2. Scope

This policy applies to:
- All requests from law enforcement agencies
- Court orders and subpoenas
- Government regulatory inquiries
- National security requests
- International authority requests

---

## 3. Required Review of Legality

### 3.1 Initial Assessment

All public authority requests MUST undergo legal review before any data is disclosed:

1. **Verify Authority Identity**
   - Confirm the requesting party is a legitimate public authority
   - Verify the identity of the requesting official
   - Document badge numbers, agency credentials, and contact information

2. **Assess Legal Basis**
   - Determine if the request is accompanied by valid legal process:
     - Subpoena
     - Court order
     - Search warrant
     - National security letter
     - Other legally binding instrument
   - Verify jurisdiction (does this authority have legal power over our operations?)

3. **Legal Counsel Review**
   - All requests MUST be reviewed by legal counsel before response
   - Emergency requests: Review within 24 hours
   - Standard requests: Review within 5 business days

### 3.2 Legality Checklist

| Checkpoint | Required | Notes |
|------------|----------|-------|
| Valid legal instrument | Yes | Must be properly issued |
| Proper jurisdiction | Yes | Authority must have jurisdiction |
| Specificity of request | Yes | Must identify specific data/users |
| Proportionality | Yes | Request must be proportionate to investigation |
| Legal counsel sign-off | Yes | Documented approval required |

---

## 4. Provisions for Challenging Unlawful Requests

### 4.1 Grounds for Challenge

We will challenge requests that are:
- **Overbroad**: Requesting more data than necessary for stated purpose
- **Lacking legal basis**: No valid warrant, subpoena, or court order
- **Jurisdictionally improper**: Authority lacks jurisdiction
- **Procedurally defective**: Improper service or format
- **Violating user rights**: Infringing on constitutional or statutory protections
- **Conflicting with other laws**: GDPR, CCPA, or other privacy regulations

### 4.2 Challenge Procedures

1. **Document Deficiencies**
   - Identify specific legal defects in the request
   - Prepare written analysis of why request is unlawful

2. **Notify Requesting Authority**
   - Send formal written response identifying deficiencies
   - Request clarification or proper legal process
   - Set reasonable deadline for response

3. **Legal Action if Necessary**
   - File motion to quash (for subpoenas)
   - File motion to modify (for overbroad requests)
   - Seek protective order from court
   - Appeal adverse rulings

4. **User Notification**
   - Unless legally prohibited (e.g., gag order), notify affected users
   - Provide users opportunity to challenge request themselves
   - Document any legal prohibition on notification

### 4.3 Challenge Response Template

```
RE: Data Request [Reference Number]

We have received your request dated [DATE] for user data.

Upon legal review, we have identified the following concerns:
- [Specific deficiency 1]
- [Specific deficiency 2]

We respectfully request that you:
[ ] Provide proper legal process
[ ] Narrow the scope of your request
[ ] Clarify jurisdiction
[ ] Other: _______________

We reserve all rights to challenge this request in court if necessary.
```

---

## 5. Data Minimization Policy

### 5.1 Principle

We will disclose ONLY the minimum information necessary to comply with valid legal requests. We will not provide more data than legally required.

### 5.2 Data Categories and Disclosure Levels

| Data Type | Disclosure Level | Notes |
|-----------|------------------|-------|
| Basic subscriber info | Level 1 | Name, email, account creation date |
| Login/IP records | Level 2 | Requires subpoena minimum |
| Game history | Level 3 | Requires court order |
| Financial transactions | Level 3 | Requires court order |
| Private communications | Level 4 | Requires search warrant |
| Full account contents | Level 4 | Requires search warrant |

### 5.3 Minimization Procedures

1. **Scope Limitation**
   - Only provide data specifically identified in legal process
   - Do not volunteer additional information
   - Redact unrelated user data from responses

2. **Time Limitation**
   - Only provide data for time periods specified
   - If no time period specified, request clarification
   - Default to narrowest reasonable interpretation

3. **User Limitation**
   - Only provide data for specifically identified users
   - Do not provide bulk data unless legally compelled
   - Challenge requests for "all users" or broad categories

4. **Format Limitation**
   - Provide data in format that limits exposure
   - Use secure transfer methods
   - Do not provide database access; provide specific records only

### 5.4 Data We Will NOT Disclose

Unless compelled by valid court order with no available challenge:
- Passwords (we don't store plaintext; hashes are useless)
- Data of users not specifically identified
- Data outside the specified time range
- Internal communications about the request
- Information about other pending requests

---

## 6. Documentation Requirements

### 6.1 Request Log

All requests MUST be logged with the following information:

```
REQUEST DOCUMENTATION FORM

Request ID: [AUTO-GENERATED]
Date Received: 
Received By:
Receiving Method: [ ] Email [ ] Mail [ ] In-Person [ ] Other

REQUESTING AUTHORITY
Agency Name:
Agency Type: [ ] Federal [ ] State [ ] Local [ ] International
Officer Name:
Badge/ID Number:
Contact Information:
Jurisdiction:

LEGAL PROCESS
Type: [ ] Subpoena [ ] Court Order [ ] Warrant [ ] NSL [ ] Other
Case Number:
Court/Issuing Authority:
Date Issued:
Expiration Date:

REQUEST DETAILS
Data Requested:
Users Affected:
Time Period:
Stated Purpose:

LEGAL REVIEW
Reviewed By:
Review Date:
Legality Assessment: [ ] Valid [ ] Deficient [ ] Challenged
Deficiencies Identified:

RESPONSE
Response Date:
Response Type: [ ] Full Compliance [ ] Partial [ ] Challenged [ ] Rejected
Data Provided:
Data Withheld:
Reasoning:

USER NOTIFICATION
Notification Permitted: [ ] Yes [ ] No (gag order)
Users Notified: [ ] Yes [ ] No [ ] N/A
Notification Date:
```

### 6.2 Response Documentation

Every response MUST include:

1. **Cover Letter**
   - Reference to original request
   - Summary of data provided
   - Statement of legal basis for disclosure
   - Any limitations or redactions applied
   - Contact for questions

2. **Data Inventory**
   - Itemized list of all data provided
   - Format and delivery method
   - Certification of completeness

3. **Legal Reasoning Memo** (internal)
   - Analysis of request validity
   - Basis for compliance or challenge
   - Minimization decisions made
   - Approving attorney signature

### 6.3 Retention

- Request documentation: 7 years minimum
- Response documentation: 7 years minimum
- Legal analysis memos: 7 years minimum
- Secure storage with access controls
- Annual audit of documentation completeness

---

## 7. Roles and Responsibilities

| Role | Responsibilities |
|------|------------------|
| **Data Protection Officer** | Receives all requests, coordinates response, maintains log |
| **Legal Counsel** | Reviews legality, approves responses, handles challenges |
| **Engineering Lead** | Extracts requested data, ensures minimization |
| **Executive Sponsor** | Final approval for sensitive disclosures |

---

## 8. Emergency Requests

For requests claiming imminent threat to life or serious injury:

1. Verify emergency claim with requesting authority
2. Expedited legal review (within 4 hours)
3. If valid emergency, provide minimum necessary data
4. Document emergency basis thoroughly
5. Follow up with formal legal process within 24 hours

---

## 9. Transparency Reporting

We will publish annual transparency reports including:
- Number of requests received (by type)
- Number of requests challenged
- Number of requests complied with (full/partial)
- Number of users affected
- Geographic breakdown of requests

User-identifying information will NOT be included in transparency reports.

---

## 10. Policy Review

This policy will be reviewed:
- Annually (minimum)
- After any significant legal request
- When laws or regulations change
- After any compliance incident

---

## 11. Contact

For questions about this policy or to submit a legal request:

**Legal Department**  
Email: legal@california.vision  
Address: 10929 Firestone Blvd Suite 173, Norwalk CA, 90650

Law enforcement requests MUST be submitted in writing with proper legal process.

---

*This policy is designed to comply with applicable privacy laws including GDPR, CCPA, and relevant data protection regulations.*
