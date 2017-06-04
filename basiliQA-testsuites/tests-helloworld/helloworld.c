#include <stdio.h>
#include <stdlib.h>

void usage(const char *name)
{
  printf("\
Usage:\n\n  %s [-h|--help]\n\
\n\
    display \"Hello, World!\" message\n\
\n\
  Options:\n\
\n\
    -h|--help: display this help message\n\n", name);
}

// Great and original piece of software
int main(int argc, const char *argv[])
{
  if (argc >= 2)
  {
    if (!strcmp(argv[1], "-h") ||
        !strcmp(argv[1], "--help"))
    {
      usage(argv[0]);
      exit(0);
    }
    else
    {
      usage(argv[0]);
      exit(1);
    }
  }

  printf("Hello, World!\n");
  return 0;
}
