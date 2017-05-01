/*
 * Parsing of basiliQA test environment files.
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

#include "../common.h"

#include <string.h>

#define OK 0
#define SYNTAX_ERROR 1
#define PARSING_ERROR 2
#define NOT_FOUND 3

// Print usage information
int usage(int rc)
{
  fprintf(rc? stderr: stdout,
    "testenv: access test environment\n"
    "\n"
    "Usage:\n"
    "  testenv [-h|--help]\n"
    "  testenv [-f|--filename <file>] <selector>\n"
    "\n"
    "Selectors:\n"
    "  name                                  name of test project\n"
    "  context                               context of testing, for parallel executions\n"
    "  parameters                            comma-separated list of test suite parameters\n"
    "  workspace                             path to test work space directory\n"
    "  report                                path to JUnit XML report file\n"
    "  ---                                   ---\n"
    "  networks                              defined networks\n"
    "  network:subnet <network>              IPv4 prefix for given network\n"
    "  network:subnet6 <network>             IPv6 prefix for given network\n"
    "  network:gateway <network>             IPv4 address of its exit gateway\n"
    "  ---                                   ---\n"
    "  nodes                                 defined nodes\n"
    "  node:target <node>                    twopence target for given node\n"
    "  node:internal-ip <node>               internal IPv4 address\n"
    "  node:external-ip <node>               external IPv4 address\n"
    "  node:ip6 <node>                       IPv6 address\n"
    "  ---                                   ---\n"
    "  interfaces <node>                     interfaces for given node\n"
    "  interface:internal-ip <node> <iface>  internal IPv4 address for given interface\n"
    "  interface:external-ip <node> <iface>  external IPv4 address for given interface\n"
    "  interface:ip6 <node> <iface>          IPv6 address for given interface\n"
    "  interface:network <node> <iface>      name of network the interface is attached to\n"
    "  ---                                   ---\n"
    "  disks <node>                          disks for given node\n"
    "  disk:size <node> <disk>               size of given disk\n"
    "\n"
    "If no filename is given, $WORKSPACE/testenv.xml is used,\n"
    "or testenv.xml if $WORKSPACE is undefined.\n"
    "\n");

  return rc;
}

// Callback
void print_result(const char *result, void *data)
{
  puts(result);
}

// Access test environment
int access_test_environment(xmlDocPtr doc, int argc, const char *argv[])
{
  const char *selector = argv[0];
  struct testenv_environment env = { doc, &print_result, NULL };

  if (!strcmp(selector, "name"))
  {
    if (argc != 1) return usage(SYNTAX_ERROR);
    return testenv_name(&env)? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "context"))
  {
    if (argc != 1) return usage(SYNTAX_ERROR);
    return testenv_context(&env)? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "parameters"))
  {
    if (argc != 1) return usage(SYNTAX_ERROR);
    return testenv_parameters(&env)? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "workspace"))
  {
    if (argc != 1) return usage(SYNTAX_ERROR);
    return testenv_workspace(&env)? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "report"))
  {
    if (argc != 1) return usage(SYNTAX_ERROR);
    return testenv_report(&env)? OK: NOT_FOUND;
  }

  // -------------------------------------------------------------------

  if (!strcmp(selector, "networks"))
  {
    if (argc != 1) return usage(SYNTAX_ERROR);
    return testenv_networks(&env)? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "network:subnet"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_network_subnet(&env, argv[1])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "network:subnet6"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_network_subnet6(&env, argv[1])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "network:gateway"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_network_gateway(&env, argv[1])? OK: NOT_FOUND;
  }

  // -------------------------------------------------------------------

  if (!strcmp(selector, "nodes"))
  {
    if (argc != 1) return usage(SYNTAX_ERROR);
    return testenv_nodes(&env)? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "node:target"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_node_target(&env, argv[1])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "node:internal-ip"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_node_internal_ip(&env, argv[1])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "node:external-ip"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_node_external_ip(&env, argv[1])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "node:ip6"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_node_ip6(&env, argv[1])? OK: NOT_FOUND;
  }

  // -------------------------------------------------------------------

  if (!strcmp(selector, "interfaces"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_interfaces(&env, argv[1])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "interface:internal-ip"))
  {
    if (argc != 3) return usage(SYNTAX_ERROR);
    return testenv_interface_internal_ip(&env, argv[1], argv[2])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "interface:external-ip"))
  {
    if (argc != 3) return usage(SYNTAX_ERROR);
    return testenv_interface_external_ip(&env, argv[1], argv[2])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "interface:ip6"))
  {
    if (argc != 3) return usage(SYNTAX_ERROR);
    return testenv_interface_ip6(&env, argv[1], argv[2])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "interface:network"))
  {
    if (argc != 3) return usage(SYNTAX_ERROR);
    return testenv_interface_network(&env, argv[1], argv[2])? OK: NOT_FOUND;
  }

  // -------------------------------------------------------------------

  if (!strcmp(selector, "disks"))
  {
    if (argc != 2) return usage(SYNTAX_ERROR);
    return testenv_disks(&env, argv[1])? OK: NOT_FOUND;
  }
  if (!strcmp(selector, "disk:size"))
  {
    if (argc != 3) return usage(SYNTAX_ERROR);
    return testenv_disk_size(&env, argv[1], argv[2])? OK: NOT_FOUND;
  }

  // -------------------------------------------------------------------

  return usage(SYNTAX_ERROR);
}

// Main program
int main(int argc, const char *argv[])
{
  char filename[256];
  xmlDocPtr doc;
  int rc;

  if (argc < 2)
    return usage(SYNTAX_ERROR);
  if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help"))
    return usage(OK);

  if (!strcmp(argv[1], "-f") || !strcmp(argv[1], "--filename"))
  {
    if (argc < 4)
      return usage(SYNTAX_ERROR);
    strncpy(filename, argv[2], 255);
    filename[255] = '\0';
    argc -= 3; argv += 3;
  }
  else
  {
    const char *workspace = getenv("WORKSPACE");
    if (workspace)
    {
      snprintf(filename, 255, "%s/testenv.xml", workspace);
      filename[255] = '\0';
    }
    else strcpy(filename, "testenv.xml");
    argc -= 1; argv += 1;
  }

  if (!(doc = xmlParseFile(filename)))
  {
    fprintf(stderr, "Test environment file %s parsing failed\n", filename);
    return PARSING_ERROR;
  }

  if ((rc = access_test_environment(doc, argc, argv)) == NOT_FOUND)
  {
    fprintf(stderr, "No results\n");
    return NOT_FOUND;
  }

  xmlFreeDoc(doc);
  xmlCleanupParser();

  return rc;
}
