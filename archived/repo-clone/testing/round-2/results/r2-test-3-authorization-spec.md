# Authorization Behavioral Specification

## Overview

This specification documents the authorization system for the TellMemo application, covering role-based access control (RBAC), organization-level permissions, project-level permissions, and multi-tenant data isolation through row-level security (RLS).

## 1. Role-Based Access Control (RBAC)

### 1.1 Member role cannot access admin-only endpoints

**Requirement**: Users with member role are denied access to administrative endpoints.

**Behavior**: When a user with member role attempts to delete an organization (admin-only operation), the system returns a 403 Forbidden or 404 Not Found status code. If the status is 403, the response includes an error detail message containing "admin" or "permission". [test:file:30-82]

**Test Data**:

- Member user created with member role in organization [test:file:38-59]
- Access token generated for member [test:file:62-66]
- DELETE endpoint: `/api/v1/organizations/{organization_id}` [test:file:69-75]

### 1.2 Admin role can access all endpoints

**Requirement**: Users with admin role have unrestricted access to protected endpoints, including those marked admin-only.

**Behavior**: When an admin user requests access to protected endpoints (such as listing organization members), the system returns either 200 OK or 404 Not Found, allowing the request to proceed (404 indicates the endpoint itself may not exist, not an authorization failure). [test:file:84-109]

**Test Data**:

- Admin user (test_user is pre-configured as admin) [test:file:92]
- Access token generated for admin [test:file:93-97]
- GET endpoint: `/api/v1/organizations/{organization_id}/members` [test:file:100-106]

## 2. Organization-Level Permissions

### 2.1 Users cannot access resources from organizations they don't belong to

**Requirement**: Users are restricted from accessing resources in organizations where they are not members.

**Behavior**: When a user attempts to access a resource from an organization where they have no membership, the system returns 403 Forbidden or 404 Not Found. [test:file:120-154]

**Test Data**:

- User token created for user's active organization [test:file:138-142]
- Attempted access to different organization: GET `/api/v1/organizations/{other_org_id}` [test:file:145-151]
- X-Organization-Id header contains the unauthorized organization [test:file:149]

### 2.2 Organization context is correctly set from X-Organization-Id header

**Requirement**: The system extracts and applies organization context from the X-Organization-Id HTTP header.

**Behavior**: When a user with valid credentials provides the X-Organization-Id header:

- The system recognizes the header and scopes the request to that organization
- A 200 OK response indicates successful retrieval
- A 404 Not Found response indicates the endpoint exists but the resource does not
- The response JSON (if 200) contains a matching organization ID [test:file:156-183]

**Test Data**:

- User token created with matching organization ID [test:file:165-169]
- GET endpoint: `/api/v1/organizations/{organization_id}` [test:file:172-178]
- X-Organization-Id header matches token organization [test:file:176]

### 2.3 Invalid organization header is handled gracefully

**Requirement**: The system handles invalid organization IDs in the X-Organization-Id header without crashing.

**Behavior**: When the X-Organization-Id header contains an invalid UUID format:

- The request completes without error
- The system returns 200 OK, 404 Not Found, or 422 Unprocessable Entity
- A 422 response indicates the system validates and rejects the malformed header
- 200/404 indicates the system logs the issue but continues processing [test:file:185-208]

**Test Data**:

- Invalid UUID format: "invalid-uuid" [test:file:202]
- GET endpoint: `/api/v1/organizations/me` [test:file:199]

### 2.4 Users can switch between multiple organizations

**Requirement**: Users who belong to multiple organizations can authenticate and access resources from any of their organizations by changing the X-Organization-Id header.

**Behavior**: When a user who is a member of multiple organizations:

1. Creates a token for one organization
2. Switches the X-Organization-Id header to a different organization they own/manage
3. The system allows access if the user is a member of that organization

Returns 200 OK or 404 Not Found; the response (if 200) contains the correct organization ID. [test:file:210-257]

**Test Data**:

- User created as admin in two organizations [test:file:219-236]
- Token created for first org [test:file:239-243]
- Request made to second org with updated header [test:file:246-252]
- GET endpoint: `/api/v1/organizations/{org2_id}` [test:file:247]

## 3. Multi-Tenant Data Isolation (RLS)

### 3.1 Users only see projects from their own organization

**Requirement**: Row-level security ensures users can only view projects belonging to their organization, even when multiple organizations share the database.

**Behavior**: When a user requests the list of all projects:

- Only projects from the user's organization are returned in the response
- Projects from other organizations are filtered out at the database/service layer
- The response (if 200) includes the user's own project ID
- The response does not include other organizations' project IDs [test:file:268-326]

**Test Data**:

- User belongs to test_organization [test:file:272]
- own_project created in test_organization [test:file:296-302]
- other_project created in a different organization [test:file:286-293]
- GET endpoint: `/api/v1/projects/` [test:file:312-318]

### 3.2 RLS context prevents cross-organization direct access

**Requirement**: Even if a user knows the exact ID of a project from another organization, they cannot access it directly.

**Behavior**: When a user attempts to access a specific project from a different organization:

- The system returns 401 Unauthorized, 403 Forbidden, or 404 Not Found
- No project data is leaked; the response does not reveal whether the project exists [test:file:328-373]

**Test Data**:

- protected_project created in other_org [test:file:347-353]
- User token for test_organization [test:file:357-361]
- Attempted GET endpoint: `/api/v1/projects/{protected_project_id}` [test:file:364-370]
- X-Organization-Id in request: test_organization (not the owner) [test:file:368]

### 3.3 Users in multiple organizations see correct data per context

**Requirement**: When a single user belongs to multiple organizations, the system returns different datasets depending on which organization context is active in the request.

**Behavior**: When a user who belongs to two organizations makes requests with different X-Organization-Id headers:

- First request with org1 context returns org1's projects only [test:file:423-430]
- Second request with org2 context returns org2's projects only [test:file:432-439]
- org1's project ID appears in org1's response but not in org2's [test:file:453-454]
- org2's project ID appears in org2's response but not in org1's [test:file:456-457]

**Test Data**:

- User (test_user) is admin in both organizations [test:file:384-401]
- project1 created in test_organization [test:file:404-408]
- project2 created in org2 [test:file:409-413]
- Two separate GET requests to `/api/v1/projects/` with different X-Organization-Id headers [test:file:424-439]

## 4. Edge Cases and Error Handling

### 4.1 Unauthenticated users cannot access protected endpoints

**Requirement**: The system rejects requests without valid authentication credentials.

**Behavior**: When a request is made without an Authorization header:

- The system returns 401 Unauthorized or 403 Forbidden
- No project data is returned [test:file:468-477]

**Test Data**:

- GET request to `/api/v1/projects/` with no Authorization header [test:file:474]

### 4.2 Invalid JWT tokens are rejected

**Requirement**: Malformed or tampered JWT tokens are rejected by the authentication middleware.

**Behavior**: When a request includes a malformed JWT token:

- The system returns 401 Unauthorized
- The token fails validation (not cryptographically signed or structurally invalid) [test:file:479-491]

**Test Data**:

- Invalid token format: "invalid.token.here" [test:file:487]
- GET endpoint: `/api/v1/projects/` [test:file:485-487]

### 4.3 Expired JWT tokens are rejected

**Requirement**: Tokens with an expiration time in the past are rejected.

**Behavior**: When a request includes a valid JWT token structure but with an expiration time (exp claim) in the past:

- The system returns 401 Unauthorized
- The token is cryptographically valid but temporally invalid [test:file:493-522]

**Test Data**:

- Token created with exp set to 1 hour before current time [test:file:505-513]
- Expired token created using HS256 algorithm [test:file:512]
- GET endpoint: `/api/v1/projects/` [test:file:516-519]

### 4.4 Users without organization membership are denied access

**Requirement**: Orphaned users (those without any organization membership) cannot access protected endpoints.

**Behavior**: When a user who has no organization membership attempts to access a protected endpoint:

- The system returns 401 Unauthorized, 403 Forbidden, or 404 Not Found
- The user may have valid authentication (valid token) but lacks organizational context [test:file:524-556]

**Test Data**:

- orphan_user created without organization membership [test:file:531-541]
- Valid token generated for orphan_user (no organization_id in token) [test:file:544-547]
- GET endpoint: `/api/v1/projects/` [test:file:550-553]

### 4.5 Removed organization members lose access immediately

**Requirement**: When a user's membership in an organization is revoked (deleted), their access is immediately denied.

**Behavior**: When a user's OrganizationMember record is deleted:

1. Before deletion, the user can access organization resources with their token [test:file:597-604]
2. After deletion from the organization, the same token is rejected [test:file:610-620]
3. The system returns 403 Forbidden or 404 Not Found on the second request [test:file:620]
4. Access is revoked even though the JWT token itself is still valid (not expired) [test:file:614]

**Test Data**:

- temp_user created and added to test_organization [test:file:566-587]
- temp_token generated (valid JWT) [test:file:590-594]
- First request succeeds (user is member) [test:file:597-604]
- OrganizationMember record deleted [test:file:606-608]
- Second request denied with same token [test:file:610-620]
- GET endpoint: `/api/v1/organizations/{organization_id}` [test:file:598, 611]

---

## Test Coverage Summary

**Total Test Classes**: 4
**Total Test Cases**: 15

| Category | Count | Details |
|----------|-------|---------|
| RBAC | 2 | Member access denial, Admin access grant |
| Organization Permissions | 4 | Cross-org denial, header context, invalid header, org switching |
| RLS/Multi-tenancy | 3 | Own-org visibility, cross-org prevention, multi-org context |
| Edge Cases | 6 | Unauthenticated, invalid token, expired token, orphan user, membership revocation |

**Source File Reference**: `/tmp/claude/tellmemo-app/backend/tests/integration/test_authorization.py`
