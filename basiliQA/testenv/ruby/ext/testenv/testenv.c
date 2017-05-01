/*
Ruby acces to test environment.

Twopence enables to communicate with some testing environment:
libvirt virtual machine, remote host via SSH, or remote host via serial lines.


Copyright (C) 2015,2016 SUSE LLC

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 2.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#include <ruby.h>

#include "common.h"

// The ruby module
VALUE Testenv = Qnil;

void deallocate_testenv(void *data);

// Callback: store enumarated value in a list
void store_result_in_list(const char *result, void *data)
{
  VALUE list = (VALUE) data;
  rb_ary_push(list, rb_str_new2(result));
}

// Get list of strings, 0 argument
VALUE get_list_0(VALUE self, bool (*get_function)(const testenv_env *env))
{
  struct testenv_environment env = { NULL, store_result_in_list, NULL };
  VALUE list = rb_ary_new();

  Data_Get_Struct(self, xmlDocPtr, env.doc);
  env.data = (void *) list;

  if (!(*get_function)(&env))
    rb_raise(rb_eStandardError, "Not found");

  return list;
}

// Get list of strings, 1 argument
VALUE get_list_1(VALUE self, VALUE arg1, bool (*get_function)(const testenv_env *env, const char *s1))
{
  struct testenv_environment env = { NULL, store_result_in_list, NULL };
  VALUE list = rb_ary_new();

  Data_Get_Struct(self, xmlDocPtr, env.doc);
  env.data = (void *) list;

  if (!(*get_function)(&env, StringValueCStr(arg1)))
    rb_raise(rb_eStandardError, "Not found");

  return list;
}

// Callback: store unique value in a string
void store_result_in_string(const char *result, void *data)
{
  VALUE *string = (VALUE *) data;
  *string = rb_str_new2(result);
}

// Get string, 0 argument
VALUE get_string_0(VALUE self, bool (*get_function)(const testenv_env *env))
{
  struct testenv_environment env = { NULL, store_result_in_string, NULL };
  VALUE string;

  Data_Get_Struct(self, xmlDocPtr, env.doc);
  env.data = (void *) &string;

  if (!(*get_function)(&env))
    rb_raise(rb_eStandardError, "Not found");

  return string;
}

// Get string, 1 argument
VALUE get_string_1(VALUE self, VALUE arg1, bool (*get_function)(const testenv_env *env, const char *s1))
{
  struct testenv_environment env = { NULL, store_result_in_string, NULL };
  VALUE string;

  Data_Get_Struct(self, xmlDocPtr, env.doc);
  env.data = (void *) &string;

  if (!(*get_function)(&env, StringValueCStr(arg1)))
    rb_raise(rb_eStandardError, "Not found");

  return string;
}

// Get string, 2 arguments
VALUE get_string_2(VALUE self, VALUE arg1, VALUE arg2, bool (*get_function)(const testenv_env *env, const char *s1, const char *s2))
{
  struct testenv_environment env = { NULL, store_result_in_string, NULL };
  VALUE string;

  Data_Get_Struct(self, xmlDocPtr, env.doc);
  env.data = (void *) &string;

  if (!(*get_function)(&env, StringValueCStr(arg1), StringValueCStr(arg2)))
    rb_raise(rb_eStandardError, "Not found");

  return string;
}

// Get test's project name
VALUE method_name(VALUE self)
{
  return get_string_0(self, testenv_name);
}

// Get test's context
VALUE method_context(VALUE self)
{
  return get_string_0(self, testenv_context);
}

// Get test's parameters
VALUE method_parameters(VALUE self)
{
  return get_string_0(self, testenv_parameters);
}

// Get test's workspace directory
VALUE method_workspace(VALUE self)
{
  return get_string_0(self, testenv_workspace);
}

// Get test's JUnit XML report file
VALUE method_report(VALUE self)
{
  return get_string_0(self, testenv_report);
}

// List the networks
VALUE method_networks(VALUE self)
{
  return get_list_0(self, testenv_networks);
}

// Get a network's IPv4 subnet
VALUE method_network_subnet(VALUE self, VALUE network)
{
  return get_string_1(self, network, testenv_network_subnet);
}

// Get a network's IPv6 subnet
VALUE method_network_subnet6(VALUE self, VALUE network)
{
  return get_string_1(self, network, testenv_network_subnet6);
}

// Get a network's gateway
VALUE method_network_gateway(VALUE self, VALUE network)
{
  return get_string_1(self, network, testenv_network_gateway);
}

// List the nodes
VALUE method_nodes(VALUE self)
{
  return get_list_0(self, testenv_nodes);
}

// Get a node's twopence target
VALUE method_node_target(VALUE self, VALUE node)
{
  return get_string_1(self, node, testenv_node_target);
}

// Get a node's internal IP
VALUE method_node_internal_ip(VALUE self, VALUE node)
{
  return get_string_1(self, node, testenv_node_internal_ip);
}

// Get a node's external IP
VALUE method_node_external_ip(VALUE self, VALUE node)
{
  return get_string_1(self, node, testenv_node_external_ip);
}

// Get a node's IPv6 address
VALUE method_node_ip6(VALUE self, VALUE node)
{
  return get_string_1(self, node, testenv_node_ip6);
}

// List the interfaces
VALUE method_interfaces(VALUE self, VALUE node)
{
  return get_list_1(self, node, testenv_interfaces);
}

// Get an interface's internal IP
VALUE method_interface_internal_ip(VALUE self, VALUE node, VALUE interface)
{
  return get_string_2(self, node, interface, testenv_interface_internal_ip);
}

// Get an interface's external IP
VALUE method_interface_external_ip(VALUE self, VALUE node, VALUE interface)
{
  return get_string_2(self, node, interface, testenv_interface_external_ip);
}

// Get an interface's IPv6 address
VALUE method_interface_ip6(VALUE self, VALUE node, VALUE interface)
{
  return get_string_2(self, node, interface, testenv_interface_ip6);
}

// Get an interface's network name
VALUE method_interface_network(VALUE self, VALUE node, VALUE interface)
{
  return get_string_2(self, node, interface, testenv_interface_network);
}

// List the disks
VALUE method_disks(VALUE self, VALUE node)
{
  return get_list_1(self, node, testenv_disks);
}

// Get a disk's size
VALUE method_disk_size(VALUE self, VALUE node, VALUE interface)
{
  return get_string_2(self, node, interface, testenv_disk_size);
}

// Initialize the test environment
VALUE method_init(VALUE self, VALUE ruby_filename)
{
  const char *filename;
  xmlDocPtr doc;
  VALUE ruby_testenv_class;

  Check_Type(ruby_filename, T_STRING);

  filename = StringValueCStr(ruby_filename);
  if (!(doc = xmlParseFile(filename)))
  {
    fprintf(stderr, "Error while parsing document %s\n", filename);
    return Qnil;
  }

  // Return a new Ruby object wrapping the C pointer
  ruby_testenv_class = rb_const_get(self, rb_intern("Testenv"));
  return Data_Wrap_Struct(ruby_testenv_class, NULL, deallocate_testenv, doc);
}

// Deallocate the test environment
void deallocate_testenv(void *data)
{
  xmlDocPtr doc = (xmlDocPtr) data;

  xmlFreeDoc(doc);
  xmlCleanupParser();
}

// Initialize the ruby native implementation
void Init_testenv()
{
  // Ruby initializations
  VALUE ruby_testenv_class;

  Testenv = rb_define_module("Testenv");
  rb_define_singleton_method(Testenv, "init", method_init, 1);

  ruby_testenv_class = rb_define_class_under(Testenv, "Testenv", rb_cObject);

  rb_define_method(ruby_testenv_class, "name", method_name, 0);
  rb_define_method(ruby_testenv_class, "context", method_context, 0);
  rb_define_method(ruby_testenv_class, "parameters", method_parameters, 0);
  rb_define_method(ruby_testenv_class, "workspace", method_workspace, 0);
  rb_define_method(ruby_testenv_class, "report", method_report, 0);

  rb_define_method(ruby_testenv_class, "networks", method_networks, 0);
  rb_define_method(ruby_testenv_class, "network_subnet", method_network_subnet, 1);
  rb_define_method(ruby_testenv_class, "network_subnet6", method_network_subnet6, 1);
  rb_define_method(ruby_testenv_class, "network_gateway", method_network_gateway, 1);

  rb_define_method(ruby_testenv_class, "nodes", method_nodes, 0);
  rb_define_method(ruby_testenv_class, "node_target", method_node_target, 1);
  rb_define_method(ruby_testenv_class, "node_internal_ip", method_node_internal_ip, 1);
  rb_define_method(ruby_testenv_class, "node_external_ip", method_node_external_ip, 1);
  rb_define_method(ruby_testenv_class, "node_ip6", method_node_ip6, 1);

  rb_define_method(ruby_testenv_class, "interfaces", method_interfaces, 1);
  rb_define_method(ruby_testenv_class, "interface_internal_ip", method_interface_internal_ip, 2);
  rb_define_method(ruby_testenv_class, "interface_external_ip", method_interface_external_ip, 2);
  rb_define_method(ruby_testenv_class, "interface_ip6", method_interface_ip6, 2);
  rb_define_method(ruby_testenv_class, "interface_network", method_interface_network, 2);

  rb_define_method(ruby_testenv_class, "disks", method_disks, 1);
  rb_define_method(ruby_testenv_class, "disk_size", method_disk_size, 2);
}
