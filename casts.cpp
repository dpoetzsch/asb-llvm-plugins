typedef int* intptr;

struct X { int x; };

int main() 
{
  int integer=1;
  int *pointer=&integer;
  long l =(long) integer + (long) pointer; 
  int z = (int) l;
  int *r= (int *) l;
  intptr ptr =(intptr) l;
  void* yetAnotherPtr = (void*) ptr;
  return 0; 
}
