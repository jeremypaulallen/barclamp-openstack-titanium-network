# Copyright 2013 Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# add VIP - sak
Chef::Log.info("============================================")
Chef::Log.info("       Quantum database.rb recipe             ")
Chef::Log.info("============================================")

admin_vip = node[:haproxy][:admin_ip]
server_root_password = node["percona"]["server_root_password"]
# end of change

# comment out, as using percona - sak
=begin
env_filter = " AND database_config_environment:database-config-#{node[:quantum][:database_instance]}" 
sqls = search(:node, "roles:database-server#{env_filter}") || [] 
if sqls.length > 0 
    sql = sqls[0] 
    sql = node if sql.name == node.name 
else 
    sql = node 
end
include_recipe "database::client" 
backend_name = Chef::Recipe::Database::Util.get_backend_name(sql) 
include_recipe "#{backend_name}::client" 
include_recipe "#{backend_name}::python-client"

db_provider = Chef::Recipe::Database::Util.get_database_provider(sql) 
db_user_provider = Chef::Recipe::Database::Util.get_user_provider(sql) 
privs = Chef::Recipe::Database::Util.get_default_priviledges(sql) 
url_scheme = backend_name
=end
# end of change


::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

# use VIP - sak
#sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil? 
sql_address = admin_vip
# end of change
Chef::Log.info("Database server found at #{sql_address}") 

# commneted out to use script - sak
=begin
db_conn = { :host => sql_address, 
            :username => "db_maker", 
            :password => sql["database"][:db_maker_password] }
=end
# end of change
props = [ {'db_name' => node[:quantum][:db][:database],
          'db_user' => node[:quantum][:db][:user],
          'db_pass' => node[:quantum][:db][:password],
          'db_conn_name' => 'sql_connection'  },
         {'db_name' => node[:quantum][:db][:ovs_database],
          'db_user' => node[:quantum][:db][:ovs_user],
          'db_pass' => node[:quantum][:db][:ovs_password],
          'db_conn_name' => 'ovs_sql_connection'}
       ]
         
# Create the Quantum Databases
props.each do |prop|
  db_name = prop['db_name']
  db_user = prop['db_user']
  db_pass = prop['db_pass']
  db_conn_name = prop['db_conn_name']

  Chef::Log.info("============================================")
  Chef::Log.info("       Quantum create database              ")
  Chef::Log.info("============================================")

  template "/tmp/quantum_grants.sql" do
    source "quantum_grants.sql.erb"
    mode 0600
    variables(
      :db_name => db_name,
      :db_user => db_user,
      :db_pass => db_pass
    )
  end

  # execute access grants
  execute "mysql-install-privileges" do
    command "/usr/bin/mysql -u root -p#{server_root_password} < /tmp/quantum_grants.sql"
    action :nothing
    subscribes :run, resources("template[/tmp/quantum_grants.sql]"), :immediately
  end

# commented out to use script- sak
=begin
    database "create #{db_name} quantum database" do
        connection db_conn
        database_name "#{db_name}"
        provider db_provider
        action :create
    end

    database_user "create #{db_user} user in #{db_name} quantum database" do
        connection db_conn
        username "#{db_user}"
        password "#{db_pass}"
        host '%'
        provider db_user_provider
        action :create
    end

    database_user "grant database access for #{db_user} user in #{db_name} quantum database" do
        connection db_conn 
        username "#{db_user}" 
        password "#{db_pass}"
        database_name "#{db_name}"
        host '%' 
        privileges privs 
        provider db_user_provider 
        action :grant 
    end
=end
#end of change
    url_scheme = "mysql"
    node[@cookbook_name][:db][db_conn_name] = "#{url_scheme}://#{db_user}:#{db_pass}@#{sql_address}/#{db_name}"
end

node.save
