CREATE
OR REPLACE FUNCTION notify_trigger() RETURNS trigger AS $trigger$
DECLARE
rec RECORD;
  dat
RECORD;
  payload
TEXT;
BEGIN

  -- Set record row depending on operation
CASE TG_OP
  WHEN 'UPDATE' THEN
     rec := NEW;
     dat
:= OLD;
WHEN 'INSERT' THEN
     rec := NEW;
WHEN 'DELETE' THEN
     rec := OLD;
ELSE
     RAISE EXCEPTION 'Unknown TG_OP: "%". Should not occur!', TG_OP;
END
CASE;

  -- Build the payload
  payload
:= json_build_object(
          'timestamp',CURRENT_TIMESTAMP,
          'action',LOWER(TG_OP),
          'schema',TG_TABLE_SCHEMA,
          'identity',TG_TABLE_NAME,
          'record',row_to_json(rec),
          'old',row_to_json(dat)
);

  -- Notify the channel
  PERFORM
pg_notify('event_channel', payload);

RETURN rec;
END;
$trigger$
LANGUAGE plpgsql;


DROP TRIGGER messages_notify ON messages;


CREATE TRIGGER messages_notify
    AFTER INSERT OR
UPDATE OR
DELETE
ON messages
    FOR EACH ROW EXECUTE PROCEDURE notify_trigger();
