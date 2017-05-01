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

#include <Python.h>

#include "../common.h"

#include <string.h>

static PyObject *TestenvError;

typedef struct
{
    PyObject_HEAD
    xmlDocPtr doc;
} Testenv;

// Handle uninitialized object
static PyObject *sequence_error()
{
  PyErr_SetString(TestenvError, "Uninitialized object");
  return NULL;
}

// Handle wrong arguments
static PyObject *arguments_error()
{
  PyErr_SetString(TestenvError, "Invalid arguments");
  return NULL;
}

// Callback: store enumerated value in a list
void store_result_in_list(const char *result, void *data)
{
  PyObject *list = (PyObject *) data;
  PyObject *s = Py_BuildValue("s", result);
  PyList_Append(list, s);
  // "s" pointer will be thrown away, we need to decrease the ref counter:
  Py_DECREF(s);
}

// Get list, 0 argument
static PyObject *get_list_0(Testenv *self, PyObject *args, bool (*get_function)(const testenv_env *env))
{
  Py_ssize_t n = PyTuple_Size(args);
  struct testenv_environment env = { self->doc, store_result_in_list, NULL };
  PyObject *list;

  if (self->doc == NULL) return sequence_error();
  if (n != 0) return arguments_error();

  list = PyList_New(0);
  env.data = (void *) list;
  if (!(*get_function)(&env))
  {
    Py_DECREF(list);
    PyErr_SetString(TestenvError, "Not found");
    return NULL;
  }

  return list;
}

// Get list, 1 argument
static PyObject *get_list_1(Testenv *self, PyObject *args, bool (*get_function)(const testenv_env *env, const char *arg1))
{
  Py_ssize_t n = PyTuple_Size(args);
  const char *arg1;
  struct testenv_environment env = { self->doc, store_result_in_list, NULL };
  PyObject *list;

  if (self->doc == NULL) return sequence_error();
  if (n != 1) return arguments_error();
  if (!PyArg_ParseTuple(args, "s", &arg1)) return arguments_error();

  list = PyList_New(0);
  env.data = (void *) list;
  if (!(*get_function)(&env, arg1))
  {
    Py_DECREF(list);
    PyErr_SetString(TestenvError, "Not found");
    return NULL;
  }

  return list;
}

// Callback: store unique value in a string
void store_result_in_string(const char *result, void *data)
{
  PyObject **string = (PyObject **) data;
  *string = Py_BuildValue("s", result);
}

// Get string, 0 arguments
static PyObject *get_string_0(Testenv *self, PyObject *args, bool (*get_function)(const testenv_env *env))
{
  Py_ssize_t n = PyTuple_Size(args);
  struct testenv_environment env = { self->doc, store_result_in_string, NULL };
  PyObject *string;

  if (self->doc == NULL) return sequence_error();
  if (n != 0) return arguments_error();

  env.data = (void *) &string;
  if (!(*get_function)(&env))
  {
    PyErr_SetString(TestenvError, "Not found");
    return NULL;
  }

  return string;
}

// Get string, 1 argument
static PyObject *get_string_1(Testenv *self, PyObject *args, bool (*get_function)(const testenv_env *env, const char *arg1))
{
  Py_ssize_t n = PyTuple_Size(args);
  const char *arg1;
  struct testenv_environment env = { self->doc, store_result_in_string, NULL };
  PyObject *string;

  if (self->doc == NULL) return sequence_error();
  if (n != 1) return arguments_error();
  if (!PyArg_ParseTuple(args, "s", &arg1)) return arguments_error();

  env.data = (void *) &string;
  if (!(*get_function)(&env, arg1))
  {
    PyErr_SetString(TestenvError, "Not found");
    return NULL;
  }

  return string;
}

// Get string, 2 arguments
static PyObject *get_string_2(Testenv *self, PyObject *args, bool (*get_function)(const testenv_env *env, const char *arg1, const char *argv2))
{
  Py_ssize_t n = PyTuple_Size(args);
  const char *arg1, *arg2;
  struct testenv_environment env = { self->doc, store_result_in_string, NULL };
  PyObject *string;

  if (self->doc == NULL) return sequence_error();
  if (n != 2) return arguments_error();
  if (!PyArg_ParseTuple(args, "ss", &arg1, &arg2)) return arguments_error();

  env.data = (void *) &string;
  if (!(*get_function)(&env, arg1, arg2))
  {
    PyErr_SetString(TestenvError, "Not found");
    return NULL;
  }

  return string;
}

// Get test project name
static PyObject *testenvobject_name(Testenv *self, PyObject *args)
{
  return get_string_0(self, args, testenv_name);
}

// Get test context
static PyObject *testenvobject_context(Testenv *self, PyObject *args)
{
  return get_string_0(self, args, testenv_context);
}

// Get test parameters
static PyObject *testenvobject_parameters(Testenv *self, PyObject *args)
{
  return get_string_0(self, args, testenv_parameters);
}

// Get test workspace directory
static PyObject *testenvobject_workspace(Testenv *self, PyObject *args)
{
  return get_string_0(self, args, testenv_workspace);
}

// Get test JUnit XML report file
static PyObject *testenvobject_report(Testenv *self, PyObject *args)
{
  return get_string_0(self, args, testenv_report);
}

// Enumerate the networks
static PyObject *testenvobject_networks(Testenv *self, PyObject *args)
{
  return get_list_0(self, args, testenv_networks);
}

// Get network IPv4 subnet
static PyObject *testenvobject_network_subnet(Testenv *self, PyObject *args)
{
  return get_string_1(self, args, testenv_network_subnet);
}

// Get network IPv6 subnet
static PyObject *testenvobject_network_subnet6(Testenv *self, PyObject *args)
{
  return get_string_1(self, args, testenv_network_subnet6);
}

// Get network gateway
static PyObject *testenvobject_network_gateway(Testenv *self, PyObject *args)
{
  return get_string_1(self, args, testenv_network_gateway);
}

// Enumerate the nodes
static PyObject *testenvobject_nodes(Testenv *self, PyObject *args)
{
  return get_list_0(self, args, testenv_nodes);
}

// Get node target
static PyObject *testenvobject_node_target(Testenv *self, PyObject *args)
{
  return get_string_1(self, args, testenv_node_target);
}

// Get node internal IP
static PyObject *testenvobject_node_internal_ip(Testenv *self, PyObject *args)
{
  return get_string_1(self, args, testenv_node_internal_ip);
}

// Get node external IP
static PyObject *testenvobject_node_external_ip(Testenv *self, PyObject *args)
{
  return get_string_1(self, args, testenv_node_external_ip);
}

// Get node IPv6 address
static PyObject *testenvobject_node_ip6(Testenv *self, PyObject *args)
{
  return get_string_1(self, args, testenv_node_ip6);
}

// Enumerate the interfaces
static PyObject *testenvobject_interfaces(Testenv *self, PyObject *args)
{
  return get_list_1(self, args, testenv_interfaces);
}

// Get interface internal IP
static PyObject *testenvobject_interface_internal_ip(Testenv *self, PyObject *args)
{
  return get_string_2(self, args, testenv_interface_internal_ip);
}

// Get interface external IP
static PyObject *testenvobject_interface_external_ip(Testenv *self, PyObject *args)
{
  return get_string_2(self, args, testenv_interface_external_ip);
}

// Get interface IPv6 address
static PyObject *testenvobject_interface_ip6(Testenv *self, PyObject *args)
{
  return get_string_2(self, args, testenv_interface_ip6);
}

// Enumerate the disks
static PyObject *testenvobject_disks(Testenv *self, PyObject *args)
{
  return get_list_1(self, args, testenv_disks);
}

// Get disk size
static PyObject *testenvobject_disk_size(Testenv *self, PyObject *args)
{
  return get_string_2(self, args, testenv_disk_size);
}

// Module methods index
static PyMethodDef Testenv_methods[] =
{
  { "name", (PyCFunction) testenvobject_name, METH_VARARGS,
    "Get name of test project."
  },
  { "context", (PyCFunction) testenvobject_context, METH_VARARGS,
    "Get context of test."
  },
  { "parameters", (PyCFunction) testenvobject_parameters, METH_VARARGS,
    "Get test suite parameters."
  },
  { "workspace", (PyCFunction) testenvobject_workspace, METH_VARARGS,
    "Get path to work space directory."
  },
  { "report", (PyCFunction) testenvobject_report, METH_VARARGS,
    "Get path to JUnit XML report file."
  },
  // --------------------------------------------------------------------------
  { "networks", (PyCFunction) testenvobject_networks, METH_VARARGS,
    "List networks."
  },
  { "network_subnet", (PyCFunction) testenvobject_network_subnet, METH_VARARGS,
    "Get IPv4 prefix for given network."
  },
  { "network_subnet6", (PyCFunction) testenvobject_network_subnet6, METH_VARARGS,
    "Get IPv6 prefix for given network."
  },
  { "network_gateway", (PyCFunction) testenvobject_network_gateway, METH_VARARGS,
    "Get exit gateway IPv4 address for given network."
  },
  // --------------------------------------------------------------------------
  { "nodes", (PyCFunction) testenvobject_nodes, METH_VARARGS,
    "List nodes."
  },
  { "node_target", (PyCFunction) testenvobject_node_target, METH_VARARGS,
    "Get twopence target for given node."
  },
  { "node_internal_ip", (PyCFunction) testenvobject_node_internal_ip, METH_VARARGS,
    "Get internal IPv4 address for given node."
  },
  { "node_external_ip", (PyCFunction) testenvobject_node_external_ip, METH_VARARGS,
    "Get external IPv4 address for given node."
  },
  { "node_ip6", (PyCFunction) testenvobject_node_ip6, METH_VARARGS,
    "Get IPv6 address for given node."
  },
  // --------------------------------------------------------------------------
  { "interfaces", (PyCFunction) testenvobject_interfaces, METH_VARARGS,
    "List interfaces."
  },
  { "interface_internal_ip", (PyCFunction) testenvobject_interface_internal_ip, METH_VARARGS,
    "Get internal IPv4 address for given node."
  },
  { "interface_external_ip", (PyCFunction) testenvobject_interface_external_ip, METH_VARARGS,
    "Get external IPv4 address for given node."
  },
  { "interface_ip6", (PyCFunction) testenvobject_interface_ip6, METH_VARARGS,
    "Get IPv6 address for given node."
  },
  // --------------------------------------------------------------------------
  { "disks", (PyCFunction) testenvobject_disks, METH_VARARGS,
    "List additional disks."
  },
  { "disk_size", (PyCFunction) testenvobject_disk_size, METH_VARARGS,
    "Get size of additional disk for given node."
  },
  // --------------------------------------------------------------------------
  { NULL, NULL, 0,
    NULL
  }
};

// Deallocate the test environment
static void Testenv_dealloc(Testenv *self)
{
  xmlFreeDoc(self->doc);
  self->doc = NULL;
  xmlCleanupParser();
}

// Create a new test environment
static PyObject *Testenv_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
  Testenv *self = (Testenv *) type->tp_alloc(type, 0);

  if (self != NULL) self->doc = NULL;

  return (PyObject *) self;
}

// Initialize the test environment
static int Testenv_init(Testenv *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = { "filename", NULL};
  const char *arg = NULL;
  char filename[256];

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|s", kwlist, &arg))
        return -1;

  if (self->doc != NULL)
    return -2;

  if (arg == NULL)
  {
    arg = getenv("WORKSPACE");
    if (arg != NULL)
    {
      snprintf(filename, 255, "%s/testenv.xml", arg);
      filename[255] = '\0';
    }
    else strcpy(filename, "testenv.xml");
  }
  else
  {
    strncpy(filename, arg, 255);
    filename[255] = '\0';
  }

  if (!(self->doc = xmlParseFile(filename)))
    return -3;

  return 0;
}

// Testenv type description
static PyTypeObject Testenv_type =
{
  PyObject_HEAD_INIT(NULL)
  0,                                        // ob_size
  "testenv.Testenv",                        // tp_name
  sizeof(Testenv),                          // tp_basicsize
  0,                                        // tp_itemsize
  (destructor) Testenv_dealloc,             // tp_dealloc
  0,                                        // tp_print
  0,                                        // tp_getattr
  0,                                        // tp_setattr
  0,                                        // tp_compare
  0,                                        // tp_repr
  0,                                        // tp_as_number
  0,                                        // tp_as_sequence
  0,                                        // tp_as_mapping
  0,                                        // tp_hash
  0,                                        // tp_call
  0,                                        // tp_str
  0,                                        // tp_getattro
  0,                                        // tp_setattro
  0,                                        // tp_as_buffer
  Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, // tp_flags
  "Test environment objects",               // tp_doc
  0,		                            // tp_traverse
  0,		                            // tp_clear
  0,		                            // tp_richcompare
  0,		                            // tp_weaklistoffset
  0,		                            // tp_iter
  0,		                            // tp_iternext
  Testenv_methods,                          // tp_methods
  0,                                        // tp_members
  0,                                        // tp_getset
  0,                                        // tp_base
  0,                                        // tp_dict
  0,                                        // tp_descr_get
  0,                                        // tp_descr_set
  0,                                        // tp_dictoffset
  (initproc) Testenv_init,                  // tp_init
  0,                                        // tp_alloc
  Testenv_new,                              // tp_new
};

// Module methods index
static PyMethodDef module_methods[] =
{
  { NULL, NULL, 0,
    NULL
  }
};

// Initialize the module
PyMODINIT_FUNC inittestenv(void)
{
  PyObject *module;

  module = Py_InitModule("testenv", module_methods);
  if (module == NULL)
    return;

  if (PyType_Ready(&Testenv_type) < 0)
    return;
  Py_INCREF(&Testenv_type);
  PyModule_AddObject(module, "Testenv", (PyObject *) &Testenv_type);

  TestenvError = PyErr_NewException("testenv.error", NULL, NULL);
  Py_INCREF(TestenvError);
  PyModule_AddObject(module, "error", TestenvError);
}
