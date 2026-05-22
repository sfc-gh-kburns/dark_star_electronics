{# ============================================================================
   persona_grants.sql
   Reusable macro that grants per-schema USAGE/SELECT/INSERT/etc. to the
   Dark Star Electronics persona database roles for a given database+schema.
   ============================================================================ #}

{% macro grant_persona_access(db, schema) %}
-- USAGE on schema for all read-capable personas
GRANT USAGE ON SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.ANALYST;
GRANT USAGE ON SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.DATA_SCIENTIST;
GRANT USAGE ON SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.ENGINEER;
GRANT USAGE ON SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.LOADER;
GRANT USAGE ON SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.ADMIN;

-- SELECT on existing tables/views to readers
GRANT SELECT ON ALL TABLES IN SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.ANALYST;
GRANT SELECT ON ALL VIEWS  IN SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.DATA_SCIENTIST;
GRANT SELECT ON ALL VIEWS  IN SCHEMA {{ db }}.{{ schema }} TO DATABASE ROLE {{ db }}.DATA_SCIENTIST;
{% endmacro %}
