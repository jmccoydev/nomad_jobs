job "postgres-sync-service" {
  datacenters = ["east-1"]
  type = "service"

  group "symmetric-process" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    task "setup-db"{
        #Should only be done after sync is initally setup, so will error on first run
        driver = "exec"
        env {
            PGPASSWORD ="password"
        }
        template {
            data = <<EOH
INSERT INTO sym_node_group_link (source_node_group_id,target_node_group_id,data_event_action) VALUES ('primary','primary','P');
INSERT INTO sym_router (router_id,source_node_group_id,target_node_group_id,router_type,router_expression,sync_on_update,sync_on_insert,sync_on_delete,use_source_catalog_schema,create_time,last_update_by,last_update_time) VALUES ('primary_2_primary', 'primary', 'primary', 'default', NULL, 1, 1, 1, 0, CURRENT_TIMESTAMP, 'console', CURRENT_TIMESTAMP);
INSERT INTO sym_parameter (external_id, node_group_id, param_key, param_value, create_time, last_update_by, last_update_time) VALUES ('ALL', 'ALL', 'push.thread.per.server.count', '10', CURRENT_TIMESTAMP, 'console', CURRENT_TIMESTAMP);
INSERT INTO sym_parameter (external_id, node_group_id, param_key, param_value) VALUES ('ALL', 'ALL', 'job.pull.period.time.ms', 2000);
INSERT INTO sym_parameter (external_id, node_group_id, param_key, param_value) VALUES ('ALL', 'ALL', 'job.push.period.time.ms', 2000);

INSERT INTO sym_trigger (trigger_id, source_schema_name, source_table_name, channel_id, sync_on_update, sync_on_insert, sync_on_delete, sync_on_update_condition, sync_on_insert_condition, sync_on_delete_condition, last_update_time, create_time)
VALUES ('public.coffee_ingredients', 'public', 'coffee_ingredients', 'default', 1, 1, 1, '1=1', '1=1', '1=1', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger (trigger_id, source_schema_name, source_table_name, channel_id, sync_on_update, sync_on_insert, sync_on_delete, sync_on_update_condition, sync_on_insert_condition, sync_on_delete_condition, last_update_time, create_time)
VALUES ('public.coffee_ingredients_id_seq', 'public', 'coffee_ingredients_id_seq', 'default', 1, 1, 1, '1=1', '1=1', '1=1', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger (trigger_id, source_schema_name, source_table_name, channel_id, sync_on_update, sync_on_insert, sync_on_delete, sync_on_update_condition, sync_on_insert_condition, sync_on_delete_condition, last_update_time, create_time)
VALUES ('public.coffees', 'public', 'coffees', 'default', 1, 1, 1, '1=1', '1=1', '1=1', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger (trigger_id, source_schema_name, source_table_name, channel_id, sync_on_update, sync_on_insert, sync_on_delete, sync_on_update_condition, sync_on_insert_condition, sync_on_delete_condition, last_update_time, create_time)
VALUES ('public.coffees_id_seq', 'public', 'coffees_id_seq', 'default', 1, 1, 1, '1=1', '1=1', '1=1', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger (trigger_id, source_schema_name, source_table_name, channel_id, sync_on_update, sync_on_insert, sync_on_delete, sync_on_update_condition, sync_on_insert_condition, sync_on_delete_condition, last_update_time, create_time)
VALUES ('public.ingredients', 'public', 'ingredients', 'default', 1, 1, 1, '1=1', '1=1', '1=1', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger (trigger_id, source_schema_name, source_table_name, channel_id, sync_on_update, sync_on_insert, sync_on_delete, sync_on_update_condition, sync_on_insert_condition, sync_on_delete_condition, last_update_time, create_time)
VALUES ('public.ingredients_id_seq', 'public', 'ingredients_id_seq', 'default', 1, 1, 1, '1=1', '1=1', '1=1', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO sym_trigger_router (trigger_id, router_id, enabled, initial_load_order, create_time, last_update_time)
VALUES ('public.coffee_ingredients', 'primary_2_primary', 1, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger_router (trigger_id, router_id, enabled, initial_load_order, create_time, last_update_time)
VALUES ('public.coffee_ingredients_id_seq', 'primary_2_primary', 1, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger_router (trigger_id, router_id, enabled, initial_load_order, create_time, last_update_time)
VALUES ('public.coffees', 'primary_2_primary', 1, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger_router (trigger_id, router_id, enabled, initial_load_order, create_time, last_update_time)
VALUES ('public.coffees_id_seq', 'primary_2_primary', 1, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger_router (trigger_id, router_id, enabled, initial_load_order, create_time, last_update_time)
VALUES ('public.ingredients', 'primary_2_primary', 1, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sym_trigger_router (trigger_id, router_id, enabled, initial_load_order, create_time, last_update_time)
VALUES ('public.ingredients_id_seq', 'primary_2_primary', 1, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
        EOH
        destination = "local/setupdb.sql"
        }
        config {
          command = "psql"
          args = [
          "-h postgres.service.consul products < local/setupdb.sql"
          ]
      }
    }
    task "symmetric-test" {
      driver = "raw_exec"
      artifact {
        source      = "https://netactuate.dl.sourceforge.net/project/symmetricds/symmetricds/symmetricds-3.12/symmetric-server-3.12.3.zip"
      }
        template {
        data = <<EOH
sync.url=http\://symds.service.${node.datacenter}.consul\:31415/sync/products-${node.datacenter}
group.id=primary
db.init.sql=
registration.url=http\://symds.service.dc1.consul\:31415/sync/products-dc1
db.driver=org.postgresql.Driver
db.user=root
db.password=password
db.url=jdbc\:postgresql\://postgres.service.${node.datacenter}.consul/products?protocolVersion\=3&stringtype\=unspecified&socketTimeout\=300&tcpKeepAlive\=true
engine.name=products-${node.datacenter}
external.id=products-${node.datacenter}
db.validation.query=select 1
cluster.lock.enabled=false
        EOH
        destination = "local/symmetric-server-3.12.3/engines/east-1.properties"
        }
      config {
          command = "local/symmetric-server-3.12.3/bin/sym"
          args = [
          ""
          ]
      }
      resources {
        #cpu    = 500
        #memory = 1024
        network {
          port "symds" {
            static = 31415
          }
        }
      }
    service {
        name = "symds"
        port = "symds"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}