/*
 * Parsing of basiliQA test environment files.
 * Statically linked common functions (was probably not worth a dynamic library)
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

#include "common.h"

#include <libxml/xpath.h>

// Get a node set matching a XPath query
// Returns NULL in case of error
xmlXPathObjectPtr testenv_get_nodeset(xmlDocPtr doc, const xmlChar *xpath)
{
  xmlXPathContextPtr context;
  xmlXPathObjectPtr result;

  context = xmlXPathNewContext(doc);
  if (context == NULL) return NULL;

  result = xmlXPathEvalExpression(xpath, context);
  xmlXPathFreeContext(context);
  if (result == NULL) return NULL;

  if (xmlXPathNodeSetIsEmpty(result->nodesetval))
  {
    xmlXPathFreeObject(result);
    return NULL;
  }

  return result;
}

// Print out attributes matching a XPath query
// The XPath query *must* query for attributes
// Returns false in case of error
bool testenv_list_attributes(const testenv_env *env, const char *xpath)
{
  xmlXPathObjectPtr result;
  xmlNodeSetPtr nodeset;
  int i;

  if (!(result = testenv_get_nodeset(env->doc, (const xmlChar *) xpath)))
    return false;

  nodeset = result->nodesetval;
  for (i = 0; i < nodeset->nodeNr; i++)
    (*env->callback)((const char *) nodeset->nodeTab[i]->children->content,
                     env->data);

  xmlXPathFreeObject(result);
  return true;
}

// ---------------------------------------------------------------------------

// Example:
//   $ testenv name
//   test-helloworld
bool testenv_name(const testenv_env *env)
{
  return testenv_list_attributes(env, "/testenv/@name");
}

// Example:
//   $ testenv context
//   with_nanny
bool testenv_context(const testenv_env *env)
{
  return testenv_list_attributes(env, "/testenv/@context");
}

// Example:
//   $ testenv parameters
//   CONFIGURE_PRECISE,NANNY
bool testenv_parameters(const testenv_env *env)
{
  return testenv_list_attributes(env, "/testenv/@parameters");
}

// Example:
//   $ testenv workspace
//   /usr/lib/jenkins/workspace/test-helloworld
bool testenv_workspace(const testenv_env *env)
{
  return testenv_list_attributes(env, "/testenv/@workspace");
}

// Example:
//   $ testenv report
//   /usr/lib/jenkins/workspace/test-helloworld/junit-results.xml
bool testenv_report(const testenv_env *env)
{
  return testenv_list_attributes(env, "/testenv/@report");
}

// ---------------------------------------------------------------------------

// Example:
//   $ testenv networks
//   fixed
//   private
bool testenv_networks(const testenv_env *env)
{
  return testenv_list_attributes(env, "/testenv/network/@name");
}

// Example:
//   $ testenv network:subnet private
//   192.168.1/24
bool testenv_network_subnet(const testenv_env *env, const char *network)
{
  char request[80];

  snprintf(request, 80, "/testenv/network[@name = \"%s\"]/@subnet", network);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv network:subnet6 private
//   192.168.1/24
bool testenv_network_subnet6(const testenv_env *env, const char *network)
{
  char request[80];

  snprintf(request, 80, "/testenv/network[@name = \"%s\"]/@subnet6", network);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv network:gateway private
//   192.168.1/24
bool testenv_network_gateway(const testenv_env *env, const char *network)
{
  char request[80];

  snprintf(request, 80, "/testenv/network[@name = \"%s\"]/@gateway", network);

  return testenv_list_attributes(env, request);
}

// ---------------------------------------------------------------------------

// Example:
//   $ testenv nodes
//   client
//   server
bool testenv_nodes(const testenv_env *env)
{
  return testenv_list_attributes(env, "/testenv/node/@name");
}

// Example:
//   $ testenv node:target client
//   ssh:10.10.10.1
bool testenv_node_target(const testenv_env *env, const char *node)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/@target", node);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv node:internal-ip client
//   192.168.1.1
bool testenv_node_internal_ip(const testenv_env *env, const char *node)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/@internal-ip", node);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv node:external-ip client
//   10.10.10.1
bool testenv_node_external_ip(const testenv_env *env, const char *node)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/@external-ip", node);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv node:ip6 client
//   fd00:c0c0::3
bool testenv_node_ip6(const testenv_env *env, const char *node)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/@ip6", node);

  return testenv_list_attributes(env, request);
}

// ---------------------------------------------------------------------------

// Example:
//   $ testenv interfaces client
//   eth0
//   eth1
bool testenv_interfaces(const testenv_env *env, const char *node)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/interface/@name", node);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv interface:internal-ip client eth0
//   192.168.1.5
bool testenv_interface_internal_ip(const testenv_env *env, const char *node, const char *interface)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/interface[@name = \"%s\"]/@internal-ip", node, interface);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv interface:external-ip client eth0
//   10.10.10.5
bool testenv_interface_external_ip(const testenv_env *env, const char *node, const char *interface)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/interface[@name = \"%s\"]/@external-ip", node, interface);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv interface:ip6 client eth1
//   fd00:c0c0::3
bool testenv_interface_ip6(const testenv_env *env, const char *node, const char *interface)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/interface[@name = \"%s\"]/@ip6", node, interface);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv interface:network client eth0
//   fixed
bool testenv_interface_network(const testenv_env *env, const char *node, const char *interface)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/interface[@name = \"%s\"]/@network", node, interface);

  return testenv_list_attributes(env, request);
}

// ---------------------------------------------------------------------------

// Example:
//   $ testenv disks client
//   /dev/vdb
//   /dev/vdc
bool testenv_disks(const testenv_env *env, const char *node)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/disk/@name", node);

  return testenv_list_attributes(env, request);
}

// Example:
//   $ testenv disk:size client /dev/vdb
//   20G
bool testenv_disk_size(const testenv_env *env, const char *node, const char *disk)
{
  char request[80];

  snprintf(request, 80, "/testenv/node[@name = \"%s\"]/disk[@name = \"%s\"]/@size", node, disk);

  return testenv_list_attributes(env, request);
}
