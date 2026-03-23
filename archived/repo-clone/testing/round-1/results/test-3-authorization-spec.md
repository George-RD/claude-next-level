# Behavioral Spec: Authorization

**Source:** backend/tests/integration/test_authorization.py
**Mode:** test
**Scope:** integration

## Behaviors

### 1. Member Role Cannot Access Admin Endpoints

**Description:** A user with "member" role in an organization is denied access to admin-only endpoints (e.g., deleting the organization). The system returns a 403 or 404 response with an error detail referencing "admin" or "permission".
**Modules Involved:** RBAC middleware, Organization API, Auth token service, Database (User, OrganizationMember)
**CROSS-CUTTING: involves 4 modules**
**Inputs:** A user with "member" role membership, a valid auth token, a DELETE request to the organization endpoint.
**Expected Output:** HTTP 403 or 404 response. If 403, the detail message contains "admin" or "permission" (case-insensitive).
**Error Cases:** Access denied for insufficient role.
**Citations:** [test:backend/tests/integration/test_authorization.py:30-82]

### 2. Admin Role Can Access All Endpoints

**Description:** A user with "admin" role in an organization can access admin-level endpoints (e.g., listing organization members).
**Modules Involved:** RBAC middleware, Organization API, Auth token service
**CROSS-CUTTING: involves 3 modules**
**Inputs:** A user with admin role, a valid auth token, a GET request to the organization members endpoint.
**Expected Output:** HTTP 200 or 404 (if endpoint not yet implemented).
**Error Cases:** None.
**Citations:** [test:backend/tests/integration/test_authorization.py:84-109]

### 3. Cross-Organization Resource Access Denied

**Description:** A user cannot access resources from an organization they do not belong to. The system enforces organization isolation at the API level.
**Modules Involved:** Organization API, Auth middleware, Database (Organization)
**CROSS-CUTTING: involves 3 modules**
**Inputs:** A user with membership in org A, a valid token for org A, a GET request targeting org B's resources.
**Expected Output:** HTTP 403 or 404 response.
**Error Cases:** Cross-organization access denied.
**Citations:** [test:backend/tests/integration/test_authorization.py:120-154]

### 4. Organization Context From Header

**Description:** The system correctly establishes organization context from the X-Organization-Id request header, allowing the user to access their own organization's data.
**Modules Involved:** Organization API, Auth middleware, Header parsing middleware
**CROSS-CUTTING: involves 3 modules**
**Inputs:** A valid auth token, X-Organization-Id header set to the user's organization ID.
**Expected Output:** HTTP 200 or 404. If 200, the response body contains the correct organization ID.
**Error Cases:** None.
**Citations:** [test:backend/tests/integration/test_authorization.py:156-181]

### 5. Invalid Organization Header Handled Gracefully

**Description:** When a request includes an invalid UUID in the X-Organization-Id header, the system handles it gracefully without crashing. It may validate and reject (422), ignore and proceed (200/404), or log the error.
**Modules Involved:** Auth middleware, Header validation
**Inputs:** A valid auth token, X-Organization-Id header set to "invalid-uuid".
**Expected Output:** HTTP 200, 404, or 422 response (system does not crash).
**Error Cases:** Invalid UUID in organization header.
**Citations:** [test:backend/tests/integration/test_authorization.py:185-208]

### 6. User Can Switch Between Organizations

**Description:** A user who belongs to multiple organizations can access each organization's resources by changing the X-Organization-Id header. The system returns the correct organization's data based on the header context.
**Modules Involved:** Organization API, Auth middleware, Database (Organization, OrganizationMember)
**CROSS-CUTTING: involves 4 modules**
**Inputs:** A user with membership in two organizations, a valid token, GET requests with different X-Organization-Id headers.
**Expected Output:** HTTP 200 or 404 for each request. If 200, each response contains the correct organization ID.
**Error Cases:** None.
**Citations:** [test:backend/tests/integration/test_authorization.py:210-257]

### 7. User Only Sees Own Organization's Projects

**Description:** When listing projects, a user only sees projects belonging to their current organization context. Projects from other organizations are excluded from the results, enforcing multi-tenant data isolation.
**Modules Involved:** Project API, RLS/data isolation layer, Auth middleware, Database (Project, Organization)
**CROSS-CUTTING: involves 4 modules**
**Inputs:** Two organizations with one project each, a user belonging to one organization, a GET request to list projects.
**Expected Output:** HTTP 200 or 401. If 200, the response contains only the user's own organization's project ID, not the other organization's project ID.
**Error Cases:** None.
**Citations:** [test:backend/tests/integration/test_authorization.py:268-326]

### 8. RLS Prevents Direct Cross-Organization Project Access

**Description:** A user cannot directly access a specific project belonging to another organization by its ID. The row-level security (or equivalent isolation mechanism) denies the request.
**Modules Involved:** Project API, RLS/data isolation layer, Auth middleware, Database (Project, Organization)
**CROSS-CUTTING: involves 4 modules**
**Inputs:** A project belonging to another organization, a valid token for the user's own organization, a GET request to the specific project endpoint.
**Expected Output:** HTTP 401, 403, or 404 response.
**Error Cases:** Cross-organization direct project access denied.
**Citations:** [test:backend/tests/integration/test_authorization.py:328-373]

### 9. Multi-Org User Sees Correct Data Per Context

**Description:** A user belonging to two organizations sees different project sets depending on which organization context (X-Organization-Id header) is active. Each context returns only that organization's projects.
**Modules Involved:** Project API, RLS/data isolation layer, Auth middleware, Database (Project, Organization, OrganizationMember)
**CROSS-CUTTING: involves 5 modules**
**Inputs:** A user in two organizations, each with one project, GET requests to list projects with different organization context headers.
**Expected Output:** HTTP 200 or 401 for each request. If both return 200, org1's project list contains project1 but not project2, and org2's project list contains project2 but not project1.
**Error Cases:** None.
**Citations:** [test:backend/tests/integration/test_authorization.py:375-457]

### 10. Unauthenticated User Denied Access

**Description:** A request without any authentication token is rejected when accessing protected endpoints.
**Modules Involved:** Auth middleware, Project API
**Inputs:** A GET request to a protected endpoint with no Authorization header.
**Expected Output:** HTTP 401 or 403 response.
**Error Cases:** Missing authentication token.
**Citations:** [test:backend/tests/integration/test_authorization.py:468-477]

### 11. Invalid Token Rejected

**Description:** A request with an invalid JWT token (not properly signed/formatted) is rejected.
**Modules Involved:** Auth middleware, JWT validation
**Inputs:** A GET request with Authorization header "Bearer invalid.token.here".
**Expected Output:** HTTP 401 response.
**Error Cases:** Malformed/invalid JWT token.
**Citations:** [test:backend/tests/integration/test_authorization.py:479-491]

### 12. Expired Token Rejected

**Description:** A request with an expired JWT token (expiration set to 1 hour in the past) is rejected.
**Modules Involved:** Auth middleware, JWT validation, Token service
**CROSS-CUTTING: involves 3 modules**
**Inputs:** A JWT token with "exp" claim set to current time minus 3600 seconds, a GET request with this token.
**Expected Output:** HTTP 401 response.
**Error Cases:** Expired JWT token.
**Citations:** [test:backend/tests/integration/test_authorization.py:493-522]

### 13. User Without Organization Membership Denied

**Description:** A user who exists but has no organization membership ("orphan user") is denied access to protected endpoints that require organization context.
**Modules Involved:** Auth middleware, Organization membership check, Database (User)
**CROSS-CUTTING: involves 3 modules**
**Inputs:** A valid user with no organization memberships, a valid auth token, a GET request to a protected endpoint.
**Expected Output:** HTTP 401, 403, or 404 response.
**Error Cases:** No organization membership.
**Citations:** [test:backend/tests/integration/test_authorization.py:524-556]

### 14. Deleted Organization Member Loses Access

**Description:** When a user's organization membership is removed from the database, subsequent requests with the same token are denied access to that organization's resources, even though the token is still valid.
**Modules Involved:** Auth middleware, Organization membership check, Database (User, OrganizationMember, Organization)
**CROSS-CUTTING: involves 4 modules**
**Inputs:** A user added to an organization, verified to have access (200 or 404), then membership record deleted. Same token used for a second request.
**Expected Output:** First request: HTTP 200 or 404 (access granted). After membership deletion, second request: HTTP 403 or 404 (access revoked).
**Error Cases:** Revoked membership with still-valid token.
**Citations:** [test:backend/tests/integration/test_authorization.py:558-620]
