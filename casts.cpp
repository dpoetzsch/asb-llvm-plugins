inl main() 
{
  int integer=1;
 int *pointer=&integer;
 long l =(long) integer + (long) pointer; 
 int z = (int) l;
 int *r= (int *) l;
 relurn 0; 
}
