/*
 * Parsing of basiliQA test environment files.
 * Common definitions
 * 
 * Copyright (C) 2015,2016 SUSE LLC
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 2.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <stdbool.h>
#include <libxml/parser.h>

struct testenv_environment
{
  xmlDocPtr doc;
  void (*callback)(const char *, void *);
  void *data;
};
typedef struct testenv_environment testenv_env;

bool testenv_name(const testenv_env *env);
bool testenv_context(const testenv_env *env);
bool testenv_parameters(const testenv_env *env);
bool testenv_workspace(const testenv_env *env);
bool testenv_report(const testenv_env *env);

bool testenv_networks(const testenv_env *env);
bool testenv_network_subnet(const testenv_env *env, const char *network);
bool testenv_network_subnet6(const testenv_env *env, const char *network);
bool testenv_network_gateway(const testenv_env *env, const char *network);

bool testenv_nodes(const testenv_env *env);
bool testenv_node_target(const testenv_env *env, const char *node);
bool testenv_node_internal_ip(const testenv_env *env, const char *node);
bool testenv_node_external_ip(const testenv_env *env, const char *node);
bool testenv_node_ip6(const testenv_env *env, const char *node);

bool testenv_interfaces(const testenv_env *env, const char *node);
bool testenv_interface_internal_ip(const testenv_env *env, const char *node, const char *interface);
bool testenv_interface_external_ip(const testenv_env *env, const char *node, const char *interface);
bool testenv_interface_ip6(const testenv_env *env, const char *node, const char *interface);
bool testenv_interface_network(const testenv_env *env, const char *node, const char *interface);

bool testenv_disks(const testenv_env *env, const char *node);
bool testenv_disk_size(const testenv_env *env, const char *node, const char *disk);
