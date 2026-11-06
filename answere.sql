# DATABASE PRACTICAL ASSIGNMENT

**Topic:** Audit Logging, Recursive CTEs, Flyway Migrations, and Database Security

## STEP 1: CREATE A REUSABLE AUDIT LOG

```sql
-- Create the audit log table
CREATE TABLE audit_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tbl TEXT,
    op TEXT,
    old_row JSONB,
    new_row JSONB,
    changed_by TEXT DEFAULT CURRENT_USER,
    at TIMESTAMPTZ DEFAULT NOW()
);

-- Create the reusable audit function
CREATE OR REPLACE FUNCTION audit()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (
        tbl, op, old_row, new_row
    )
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE
            WHEN TG_OP IN ('UPDATE', 'DELETE')
            THEN TO_JSONB(OLD)
            ELSE NULL
        END,
        CASE
            WHEN TG_OP IN ('INSERT', 'UPDATE')
            THEN TO_JSONB(NEW)
            ELSE NULL
        END
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create an audit trigger for the students table
CREATE TRIGGER trg_audit
AFTER INSERT OR UPDATE OR DELETE
ON students
FOR EACH ROW
EXECUTE FUNCTION audit();

-- Verify the trigger
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trg_audit';
```

## STEP 2: TEST THE AUDIT LOG

```sql
-- Update a student record
UPDATE students
SET name = 'Kofi M.'
WHERE id = 1;

-- Delete a student record
DELETE FROM students
WHERE id = 3;

-- Display audit records
SELECT
    tbl,
    op,
    old_row->>'name' AS was,
    new_row->>'name' AS now,
    changed_by,
    at
FROM audit_log
ORDER BY at DESC, id DESC;

-- Count audit records
SELECT COUNT(*) AS total_audit_records
FROM audit_log;
```

## STEP 3: CREATE A HIERARCHICAL CATEGORY TREE

```sql
-- Create the categories table
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name TEXT,
    parent_id INT REFERENCES categories(id)
);

-- Insert category records
INSERT INTO categories (name, parent_id) VALUES
    ('Electronics', NULL),
    ('Computers', 1),
    ('Laptops', 2),
    ('Phones', 1);

-- Display the hierarchical category tree
WITH RECURSIVE tree AS (
    SELECT
        id,
        name,
        parent_id,
        0 AS depth
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        c.id,
        c.name,
        c.parent_id,
        t.depth + 1
    FROM categories c
    JOIN tree t
        ON c.parent_id = t.id
)
SELECT
    REPEAT('  ', depth) || name AS tree
FROM tree
ORDER BY depth, name;
```

## STEP 4: APPLY VERSIONED SCHEMA MIGRATIONS USING FLYWAY

**Migration folder structure**

```text
database-practical/
└── migrations/
    ├── V1__core_tables.sql
    ├── V2__audit_log.sql
    └── V3__categories.sql
```

**FILE 1: V1__core_tables.sql**

```sql
-- Create the students table
CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);
```

**FILE 2: V2__audit_log.sql**

```sql
-- Create the audit log table
CREATE TABLE audit_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tbl TEXT,
    op TEXT,
    old_row JSONB,
    new_row JSONB,
    changed_by TEXT DEFAULT CURRENT_USER,
    at TIMESTAMPTZ DEFAULT NOW()
);

-- Create the audit function
CREATE OR REPLACE FUNCTION audit()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (
        tbl, op, old_row, new_row
    )
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE
            WHEN TG_OP IN ('UPDATE', 'DELETE')
            THEN TO_JSONB(OLD)
            ELSE NULL
        END,
        CASE
            WHEN TG_OP IN ('INSERT', 'UPDATE')
            THEN TO_JSONB(NEW)
            ELSE NULL
        END
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create the audit trigger
CREATE TRIGGER trg_audit
AFTER INSERT OR UPDATE OR DELETE
ON students
FOR EACH ROW
EXECUTE FUNCTION audit();
```

**FILE 3: V3__categories.sql**

```sql
-- Create the categories table
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name TEXT,
    parent_id INT REFERENCES categories(id)
);

-- Insert category records
INSERT INTO categories (name, parent_id) VALUES
    ('Electronics', NULL),
    ('Computers', 1),
    ('Laptops', 2),
    ('Phones', 1);
```

**RUN FLYWAY COMMANDS IN THE TERMINAL**

```bash
-- Apply database migrations
flyway -url=jdbc:postgresql://localhost:5432/bootcamp -user=postgres -locations=filesystem:migrations migrate

-- Check migration status
flyway -url=jdbc:postgresql://localhost:5432/bootcamp -user=postgres -locations=filesystem:migrations info
```

**VERIFY MIGRATION HISTORY**

```sql
-- Display installed migrations
SELECT
    installed_rank,
    version,
    description,
    success
FROM flyway_schema_history
ORDER BY installed_rank;
```

## STEP 5: ENFORCE LEAST-PRIVILEGE DATABASE SECURITY

```sql
-- Create database roles
CREATE ROLE app_read;
CREATE ROLE app_write;

-- Grant database connection privileges
GRANT CONNECT ON DATABASE bootcamp
TO app_read, app_write;

-- Grant schema access
GRANT USAGE ON SCHEMA public
TO app_read, app_write;

-- Grant read-only permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public
TO app_read;

-- Grant read and write permissions
GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
TO app_write;

-- Grant sequence permissions
GRANT USAGE, SELECT
ON ALL SEQUENCES IN SCHEMA public
TO app_write;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO app_read;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLES TO app_write;

-- Set default privileges for future sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO app_write;

-- Create the API login user
CREATE USER api
WITH LOGIN PASSWORD 'Replace-With-A-Strong-Password';

-- Assign the write role to the API user
GRANT app_write TO api;

-- Verify database roles
SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolname IN ('app_read', 'app_write', 'api');

-- Verify role membership
SELECT
    member.rolname AS username,
    role.rolname AS assigned_role
FROM pg_auth_members m
JOIN pg_roles role
    ON role.oid = m.roleid
JOIN pg_roles member
    ON member.oid = m.member
WHERE member.rolname = 'api';
```

## FINAL VERIFICATION

```sql
-- Check students table
SELECT * FROM students;

-- Check audit records
SELECT * FROM audit_log;

-- Check category records
SELECT * FROM categories;

-- Check migration history
SELECT * FROM flyway_schema_history;

-- Check database roles
SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolname IN ('app_read', 'app_write', 'api');
```
