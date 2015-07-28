typedef int* intptr;

int main() 
{
  int integer=1;
 int *pointer=&integer;
 long l =(long) integer + (long) pointer; 
 int z = (int) l;
 int *r= (int *) l;
 intptr ptr =(intptr) l;
 return 0; 
}
