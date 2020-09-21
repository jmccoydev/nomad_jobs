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