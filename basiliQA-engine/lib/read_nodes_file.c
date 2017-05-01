/* read-nodes-file.c
   basiliQA utility to read the node file

  Copyright (C) 2017 SUSE LLC

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

#include <stdio.h>
#include <malloc.h>
#include <string.h>
#include <stdlib.h>

int num_runs = 0, in_correct_run = 0;
char line[256];
char *nodes = NULL, *networks = NULL;
char *keep = NULL, *node = NULL, *network = NULL;
char *dhcp = NULL, *gateway = NULL, *subnet = NULL, *subnet6 = NULL;
char *model = NULL, *uninstall = NULL, *repo = NULL, *install = NULL, *refresh = NULL, *nic = NULL, *disk = NULL;

void usage(FILE *fp)
{
  fprintf(fp, "Usage:\n");
  fprintf(fp, "  read-nodes-file [-l|--list] <filename>\n");
  fprintf(fp, "    list runs\n");
  fprintf(fp, "  read_nodes_file <run> <filename>\n");
  fprintf(fp, "    decode run\n");
  fprintf(fp, "  read_nodes_file [-h|--help]\n");
  fprintf(fp, "    this help information\n");
  fprintf(fp, "\n");
}

void syntax(const char *line)
{
  fprintf(stderr, "Each line should be made of a keyword and a value\n");
  fprintf(stderr, "  in: \"%s\"\n", line);
}

int is_space(char c)
{
  switch (c)
  {
    case ' ': case '\t': case '\r': case '\n':
      return 1;
  }
  return 0;
}

void trim_right(char *line)
{
  char *p = line;

  // Search comment sign
  while (*p)
  {
    if (*p == '#')
    {
      *p = '\0';
      break;
    }
    p++;
  }
  p--;

  // Trim right space
  while (p >= line && is_space(*p))
  {
    *p = '\0';
    *p--;
  }
}

void parse_line(char *line, char **keyword, char **value)
{
  char *p = line;

  // Skip initial whitespace
  while (*p && is_space(*p))
    p++;
  *keyword = p;

  // Process empty lines
  if (!*p)
  {
    *value = p;
    return;
  }

  // Find end of keyword
  while (*p && !is_space(*p))
    p++;

  // Process lines with keyword but no value
  if (!*p)
  {
    *value = p;
    return;
  }

  // Separate keyword from value
  *p++ = '\0';

  // Skip second whitespace
  while (*p && is_space(*p))
    p++;

  *value = p;
}

void set_value(char **name, const char *value)
{
  if (*name != NULL) free(*name);
  *name = malloc(strlen(value) + 1);
  strcpy(*name, value);
}

void set_value_upper(char **name, const char *value)
{
  char *p; const char *q;

  if (*name != NULL) free(*name);
  *name = malloc(strlen(value) + 1);
  p = *name; q = value;
  while (*q) *p++ = toupper(*q++);
  *p = '\0';
}

void append_value(char **name, const char *value)
{
  char *previous = *name;
  *name = malloc(strlen(previous) + strlen(value) + 1);
  strcpy(*name, previous);
  free(previous);
  strcat(*name, value);
}

void append_value_list(char **name, const char *value)
{
  if (*name == NULL)
  {
    set_value(name, value);
    return;
  }
  if (!strcmp(*name, ""))
  {
    set_value(name, value);
    return;
  }
  append_value(name, " ");
  append_value(name, value);
}

void drop_value(char **name)
{
  if (*name == NULL) return;
  free(*name);
  *name = NULL;
}

void print_network_options()
{
  printf("network-options \"%s\" \"%s\" \"%s\" \"%s\" \"%s\";\n", network, dhcp, gateway, subnet, subnet6);
}

void print_node_options()
{
  printf("node-options \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\";\n", node, model, uninstall, repo, install, refresh, nic, disk);
}

void print_global_options()
{
  printf("global-options \"%s\";\n", keep);
}

void print_node_list()
{
  printf("NODES=\"%s\";\n", nodes == NULL? "": nodes);
}

void print_network_list()
{
  printf("NETWORKS=\"%s\";\n", networks == NULL? "": networks);
}

int decode_run_keyword_value(const char *keyword, const char *value)
{
  if (!strcmp(keyword, "keep"))
  {
    if (network != NULL)
    {
      fprintf(stderr, "\"%s\" is a global option, it can't appear in a network group\n", keyword);
      return 4;
    }
    if (node != NULL)
    {
      fprintf(stderr, "\"%s\" is a global option, it can't appear in a node group\n", keyword);
      return 4;
    }
    if (!strcmp(value, "off") || !strcmp(value, "no"))
      set_value(&keep, "no");
    else if (!strcmp(value, "on") || !strcmp(value, "yes"))
      set_value(&keep, "yes");
    else
    {
      fprintf(stderr, "\"%s\" must be either \"yes\" or \"no\"\n", keyword);
      return 4;
    }
  }
  else if (!strcmp(keyword, "network"))
  {
    if (network != NULL)
    {
      print_network_options();
      drop_value(&network);
    }
    if (node != NULL)
    {
      print_node_options();
      drop_value(&node);
    }
    append_value_list(&networks, value);
    set_value_upper(&network, value);
    set_value(&dhcp, "yes");
    set_value(&gateway, "yes");
    set_value(&subnet, "");
    set_value(&subnet6, "");
  }
  else if (!strcmp(keyword, "subnet") || !strcmp(keyword, "subnet4"))
  {
    if (network == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"network\" definition\n", keyword);
      return 4;
    }
    if (!strcmp(subnet, ""))
      set_value(&subnet, value);
    else
    {
      // TODO: one could make use of several IPv4 subnets per network
      fprintf(stderr, "For the time being, only one IPv4 subnet per network is enabled\n");
      return 4;
    }
  }
  else if (!strcmp(keyword, "subnet6"))
  {
    if (network == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"network\" definition\n", keyword);
      return 4;
    }
    if (!strcmp(subnet6, ""))
      set_value(&subnet6, value);
    else
    {
      // TODO: one could make use of several IPv6 subnets per network
      fprintf(stderr, "For the time being, only one IPv6 subnet per network is enabled\n");
      return 4;
    }
  }
  else if (!strcmp(keyword, "dhcp-pool") || !strcmp(keyword, "dhcp") || !strcmp(keyword, "pool"))
  {
    if (network == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"network\" definition\n", keyword);
      return 4;
    }
    if (!strcmp(value, "off") || !strcmp(value, "no"))
      set_value(&dhcp, "no");
    else if (!strcmp(value, "on") || !strcmp(value, "yes"))
      set_value(&dhcp, "yes");
    else
    {
      // TODO: one could imagine one DHCP pool per subnet
      // TODO: it should be possible to give explicitely the DHCP range
      fprintf(stderr, "\"%s\" must be either \"yes\" or \"no\"", keyword);
      return 4;
    }
  }
  else if (!strcmp(keyword, "gateway") || !strcmp(keyword, "gw"))
  {
    if (network == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"network\" definition\n", keyword);
      return 4;
    }
    if (!strcmp(value, "off") || !strcmp(value, "no"))
      set_value(&dhcp, "no");
    else if (!strcmp(value, "on") || !strcmp(value, "yes"))
      set_value(&dhcp, "yes");
    else
    {
      // TODO: one could imagine one gateway per subnet
      // TODO: it should be possible to give explicitely the gateway address
      fprintf(stderr, "\"%s\" must be either \"yes\" or \"no\"", keyword);
      return 4;
    }
  }
  else if (!strcmp(keyword, "node") || !strcmp(keyword, "vm"))
  {
    char *default_model = getenv("VM_MODEL");
    if (network != NULL)
    {
      print_network_options();
      drop_value(&network);
    }
    if (node != NULL)
    {
      print_node_options();
      drop_value(&node);
    }
    append_value_list(&nodes, value);
    set_value_upper(&node, value);
    set_value(&model, default_model == NULL? "": default_model);
    set_value(&uninstall, "");
    set_value(&repo, "");
    set_value(&install, "");
    set_value(&refresh, "no");
    set_value(&nic, "");
    set_value(&disk, "");
  }
  else if (!strcmp(keyword, "model") || !strcmp(keyword, "flavor") || !strcmp(keyword, "flavour"))
  {
    if (node == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"node\" definition\n", keyword);
      return 4;
    }
    if (!strcmp(value, "m1.tiny") || !strcmp(value, "m1.smaller") || !strcmp(value, "m1.small") || !strcmp(value, "m1.medium") ||
        !strcmp(value, "m1.large") || !strcmp(value, "m1.xlarge") || !strcmp(value, "m1.ltp"))
      set_value(&model, value);
    else
    {
      fprintf(stderr, "\"%s\" must be one of \"m1.tiny\", \"m1.smaller\", \"m1.small\", \"m1.medium\", \"m1.large\", \"m1.xlarge\" and \"m1.ltp\"", keyword);
      return 4;
    }
  }
  else if (!strcmp(keyword, "uninstall") || !strcmp(keyword, "uninstall-package") || !strcmp(keyword, "remove") || !strcmp(keyword, "remove-package"))
  {
    if (node == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"node\" definition\n", keyword);
      return 4;
    }
    append_value_list(&uninstall, value);
  }
  else if (!strcmp(keyword, "repo") || !strcmp(keyword, "repository"))
  {
    if (node == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"node\" definition\n", keyword);
      return 4;
    }
    append_value_list(&repo, value);
  }
  else if (!strcmp(keyword, "install") || !strcmp(keyword, "install-package") || !strcmp(keyword, "package"))
  {
    if (node == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"node\" definition\n", keyword);
      return 4;
    }
    append_value_list(&install, value);
  }
  else if (!strcmp(keyword, "refresh") || !strcmp(keyword, "upgrade") || !strcmp(keyword, "refresh-packages") || !strcmp(keyword, "upgrade-packages"))
  {
    if (node == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"node\" definition\n", keyword);
      return 4;
    }
    if (!strcmp(value, "off") || !strcmp(value, "no"))
      set_value(&refresh, "no");
    else if (!strcmp(value, "on") || !strcmp(value, "yes"))
      set_value(&refresh, "yes");
    else
    {
      fprintf(stderr, "\"%s\" must be either \"yes\" or \"no\"", keyword);
      return 4;
    }
  }
  else if (!strcmp(keyword, "eth") || !strcmp(keyword, "ethernet") || !strcmp(keyword, "eth-card") || !strcmp(keyword, "ethernet-card") || !strcmp(keyword, "nic"))
  {
    if (node == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"node\" definition\n", keyword);
      return 4;
    }
    append_value_list(&nic, value);
  }
  else if (!strcmp(keyword, "disk") || !strcmp(keyword, "hard-disk") || !strcmp(keyword, "volume"))
  {
    if (node == NULL)
    {
      fprintf(stderr, "\"%s\" must be inside a \"node\" definition\n", keyword);
      return 4;
    }
    append_value_list(&disk, value);
  }
  else
  {
    fprintf(stderr, "Unknown keyword \"%s\" in nodes file\n", keyword);
    return 4;
  }
}

int list_runs_line(char *line)
{
  char *keyword, *value;

  // Parse line
  trim_right(line);
  parse_line(line, &keyword, &value);

  // Ignore white lines
  if (!*keyword)
    return 0;

  // If there's a keyword, there must be a value
  if (!*value)
  {
    syntax(line);
    return 3;
  }

  // Print run's name
  if (!strcmp(keyword, "run"))
  {
    num_runs++;
    printf("%s\n", value);
  }
  else if (!num_runs)
  {
    num_runs++;
    printf("default\n");
  }

  return 0;
}

int decode_run_line(const char *run, char *line)
{
  char *keyword, *value;

  // Parse line
  trim_right(line);
  parse_line(line, &keyword, &value);

  // Ignore white lines
  if (!*keyword)
    return 0;

  // If there's a keyword, there must be a value
  if (!*value)
  {
    syntax(line);
    return 3;
  }

  // Decode line
  if (!strcmp(keyword, "run"))
  {
    num_runs++;
    in_correct_run = !strcmp(value, run);
  }
  else
  {
    if (!num_runs)
    {
      num_runs++;
      in_correct_run = !strcmp("default", run);
    }
    if (in_correct_run)
    {
      decode_run_keyword_value(keyword, value);
    }
  }
  return 0;
}

int list_runs(const char *filename)
{
  FILE *fp = fopen(filename, "r");
  int rc = 0;

  if (fp == NULL)
  {
    fprintf(stderr, "Can't read nodes file %s\n", filename);
    return 2;
  }
  while (rc == 0 && fgets(line, sizeof(line), fp))
  {
    rc = list_runs_line(line);
  }
  close(fp);
  return rc;
}

int decode_run(const char *run, const char *filename)
{
  FILE *fp = fopen(filename, "r");
  int rc = 0;

  set_value(&keep, "no");
  if (fp == NULL)
  {
    fprintf(stderr, "Can't read nodes file %s\n", filename);
    return 2;
  }
  while (rc == 0 && fgets(line, sizeof(line), fp))
  {
    rc = decode_run_line(run, line);
  }
  close(fp);

  if (network != NULL) print_network_options();
  if (node != NULL) print_node_options();
  print_global_options();

  print_node_list();
  print_network_list();
  return rc;
}

int main(int argc, const char **argv)
{
  int rc = 0;

  switch (argc)
  {
    case 2:
      if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help"))
      {
        usage(stdout);
      }
      else
      {
        usage(stderr);
        rc = 1;
      }
      break;
    case 3:
      if (!strcmp(argv[1], "-l") || !strcmp(argv[1], "--list"))
      {
        rc = list_runs(argv[2]);
      }
      else
      {
        rc = decode_run(argv[1], argv[2]);
      }
      break;
    default:
      usage(stderr);
      rc = 1;
  }
  return rc;
}
