%{
#include <stdio.h>
#include "attr.h"
#include "instrutil.h"
int yylex();
void yyerror(char * s);
#include "symtab.h"

FILE *outfile;
char *CommentBuffer;
 
%}

%union {tokentype token;
        regInfo targetReg;
       varType variableType;
	statementInfo statement;
	variableLinkedList variableList;
	conditionalInfo conditional;}

%token PROG PERIOD VAR 
%token INT BOOL PRT THEN IF DO FI ENDWHILE ENDFOR
%token ARRAY OF 
%token BEG END ASG  
%token EQ NEQ LT LEQ GT GEQ AND OR TRUE FALSE
%token WHILE FOR ELSE 
%token <token> ID ICONST 

%type <targetReg> exp 
%type <targetReg> lhs condexp ctrlexp
%type <variableType> type stype
%type <statement> stmt
%type <variableList> vardcl idlist
%type <conditional> ifhead
%type <conditional> fstmt
%type <conditional> wstmt

%start program

%nonassoc EQ NEQ LT LEQ GT GEQ 
%left '+' '-' AND
%left '*' OR

%nonassoc THEN
%nonassoc ELSE

%%
program : {emitComment("Assign STATIC_AREA_ADDRESS to register \"r0\"");
           emit(NOLABEL, LOADI, STATIC_AREA_ADDRESS, 0, EMPTY);} 
           PROG ID ';' block PERIOD { }
	;

block	: variables cmpdstmt { }
	;

variables: /* empty */
	| VAR vardcls { }
	;

vardcls	: vardcls vardcl ';' { }
	| vardcl ';' { }
	| error ';' { yyerror("***Error: illegal variable declaration\n");}  
	;

vardcl	: idlist ':' type { varNode *current_node = $1.head;
			    varNode *previous_node;
			    while (current_node != NULL){
				int array;
				int var_offset;
				if ($3.array == 1){
					var_offset = NextOffset($3.array_size);
					array = 1;
				}
				else {
					array = 0;
					var_offset = NextOffset(1);
				}
				Type_Expression var_type = $3.type;
				SymTabEntry *entry = lookup(current_node->name);
				if (entry != NULL){
					printf("\n***Error: duplicate declaration of %s\n", current_node->name);
				}
				if (entry == NULL){
					insert(current_node->name, var_type, var_offset, array);
				}
				previous_node = current_node;
				current_node = current_node->next;
				free(previous_node);
			    }}
	;

idlist	: idlist ',' ID { 
			  $$.head = $1.head;
			   varNode *newNode = (varNode *)malloc(sizeof(varNode));
			  newNode->name = $3.str;
			  varNode *current_node = $$.head;
			  while (current_node->next != NULL){
				current_node = current_node->next;
			  }
			  current_node->next = newNode;
			  newNode->next = NULL;
			}
        | ID		{ 
			  varNode *newNode = (varNode *)malloc(sizeof(varNode));
			  newNode->name = $1.str;
			  $$.head = newNode; } 
	;


type	: ARRAY '[' ICONST ']' OF stype { int size = $3.num; 
					$$.array = 1;
					$$.type = $6.type;
					$$.array_size = $3.num;
					  }

        | stype { $$.type = $1.type;
		  $$.array = $1.array; }
	;

stype	: INT { $$.type = TYPE_INT;
		$$.array = 0; }
        | BOOL { $$.type = TYPE_BOOL;
		 $$.array = 0; }
	;

stmtlist : stmtlist ';' stmt { }
	| stmt { }
        | error { yyerror("***Error: ';' expected or illegal statement \n");}
	;

stmt    : ifstmt { }
	| fstmt { }
	| wstmt { }
	| astmt { }
	| writestmt { }
	| cmpdstmt { }
	;

cmpdstmt: BEG stmtlist END { }
	;

ifstmt :  ifhead 
          THEN { emit($1.label1, NOP, EMPTY, EMPTY, EMPTY);}
          stmt { emit(NOLABEL, BR, $1.label3, EMPTY, EMPTY); } 
  	  ELSE {emit($1.label2, NOP, EMPTY, EMPTY, EMPTY);}
          stmt {emit($1.label3, NOP, EMPTY, EMPTY, EMPTY);}
          FI
	;

ifhead : IF condexp {   $$.label1 = NextLabel(); $$.label2 = NextLabel(); $$.label3 = NextLabel();
			if ($2.type == TYPE_INT){
				printf("***Error: exp in if stmt must be boolean\n");
			}
			emit(NOLABEL, CBR, $2.targetRegister, $$.label1, $$.label2); }
        ;

writestmt: PRT '(' exp ')' { int printOffset = -4; /* default location for printing */
  	                         sprintf(CommentBuffer, "Code for \"PRINT\" from offset %d", printOffset);
	                         emitComment(CommentBuffer);
                                 emit(NOLABEL, STOREAI, $3.targetRegister, 0, printOffset);
                                 emit(NOLABEL, 
                                      OUTPUTAI, 
                                      0,
                                      printOffset, 
                                      EMPTY);
                               }
	;

fstmt	: FOR 
	  ctrlexp {int nextLabel = NextLabel(); emit(nextLabel, NOP, EMPTY, EMPTY, EMPTY);
		   int otherRegister = $2.targetRegister + 1;
		   int nextReg1 = NextRegister();
		   int nextReg2 = NextRegister();
		   char *name = $2.name;
		   SymTabEntry *entry = lookup(name); 
		   int nextLabel2= NextLabel();
		   int nextLabel3 = NextLabel();
		   emit(NOLABEL, LOADAI, 0, entry->offset, nextReg1);
		   emit(NOLABEL, CMPLE, nextReg1, otherRegister, nextReg2);
		   emit(NOLABEL, CBR, nextReg2, nextLabel2, nextLabel3);
		   emit(nextLabel2, NOP, EMPTY, EMPTY, EMPTY);
		   $2.label3 = nextLabel3;
		   $2.label1 = nextLabel;
		  }
		   
	  DO stmt { 
				char *name = $2.name;
				SymTabEntry *entry = lookup(name);
				int nextReg3 = NextRegister();
				int nextReg4 = NextRegister();
				emit(NOLABEL, LOADAI, 0, entry->offset, nextReg3);
				emit(NOLABEL, ADDI, nextReg3, 1, nextReg4);
				emit(NOLABEL, STOREAI, nextReg4, 0, entry->offset);
				emit(NOLABEL, BR, $2.label1, EMPTY, EMPTY);
				emit($2.label3, NOP, EMPTY, EMPTY, EMPTY);
				} 
          ENDFOR
	;

wstmt	: {int label1 = NextLabel();
	   emit(label1, NOP, EMPTY, EMPTY, EMPTY);}
	  WHILE condexp { 
			if ($3.type == TYPE_INT){
				printf("***Error: exp in while stmt must be boolean\n");
			} 
			$3.label2 = NextLabel(); 
			$3.label1 = $3.label2 - 1; 
			$3.label3 = NextLabel();
			emit(NOLABEL, CBR, $3.targetRegister, $3.label2, $3.label3); } 
	  DO {emit($3.label2, NOP, EMPTY, EMPTY, EMPTY);}
	  stmt {emit(NOLABEL, BR, $3.label1, EMPTY, EMPTY);}
          ENDWHILE { emit($3.label3, NOP, EMPTY, EMPTY, EMPTY); }
        ;
  

astmt : lhs ASG exp             { 
 				  if (! ((($1.type == TYPE_INT) && ($3.type == TYPE_INT)) || 
				         (($1.type == TYPE_BOOL) && ($3.type == TYPE_BOOL)))) {
				    printf("*** ERROR ***: Assignment types do not match.\n");
				  }
				  SymTabEntry *entry = lookup($1.name);
				  if (entry == NULL){
				  	printf("\n***Error: undeclared identifier %s\n", $1.name);
				  }
				  else {
					  if (entry->array == 1){
						int newReg1 = NextRegister();
						int newReg2 = NextRegister();
						int newReg3 = NextRegister();
						int newReg4 = NextRegister();
						emit(NOLABEL, LOADI, 4, newReg1, EMPTY);
						emit(NOLABEL, LOADI, entry->offset, newReg2, EMPTY);
						emit(NOLABEL, MULT, newReg1, $1.targetRegister, newReg3);
						emit(NOLABEL, ADD, newReg2, newReg3, newReg4);
						emit(NOLABEL, STOREAO, $3.targetRegister, 0, newReg4);
					  }
					  else {
						emit(NOLABEL, STOREAI, $3.targetRegister, 0, entry->offset);
					  }
				  }
                                }
	;

lhs	: ID			{ /* BOGUS  - needs to be fixed */
				  char *name = $1.str;
				  SymTabEntry *result = lookup(name);
				  if (result == NULL){
				  	printf("\n***Error: undeclared identifier %s\n", name);
				  }
				  else {
					if (result->array == 1){
						printf("\n***Error: assignment to whole array\n");
					}
				  	$$.name = name;
				  	$$.type = result->type;
				  }
                         	  }


                                |  ID '[' exp ']' {  if ($3.type != TYPE_INT){
							  printf("\n***Error: subscript exp not type integer\n");
						     }
						     char *name = $1.str;
						     SymTabEntry *entry = lookup(name);
						     if (entry == NULL){
				  			  printf("\n***Error: undeclared identifier %s\n", name);
				 		     }
						     else {
						     	if (entry->array != 1){
								printf("\n***Error: id %s is not an array\n", name);
						    	 }
						    	 $$.targetRegister = $3.targetRegister;
						    	 $$.name = name;
						    	 $$.type = entry->type;
						     }
						 }
                                ;


exp	: exp '+' exp		{ int newReg = NextRegister();

                                  if (!(($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
    				    printf("\n***Error: types of operands for operation + do not match\n");
                                  }
                                  $$.type = TYPE_INT;
				  $$.num = $1.num + $3.num;
                                  $$.targetRegister = newReg;
                                  emit(NOLABEL, 
                                       ADD, 
                                       $1.targetRegister, 
                                       $3.targetRegister, 
                                       newReg);
                                }

        | exp '-' exp		{ int newReg = NextRegister();
				  if (! (($1.type == TYPE_INT) && ($3.type == TYPE_INT))){
				     printf("\n***Error: types of operands for operation - do not match\n");
				  } 
				  $$.type = TYPE_INT;
				  $$.targetRegister = newReg;
				  $$.num = $1.num - $3.num;
				  emit(NOLABEL, SUB, $1.targetRegister, $3.targetRegister, newReg);
				}

        | exp '*' exp		{  int newReg = NextRegister();
				  if (! (($1.type == TYPE_INT) && ($3.type == TYPE_INT))){
				     printf("\n***Error: types of operands for operation * do not match\n");
				  } 
				  $$.type = TYPE_INT;
				  $$.num = $1.num * $3.num;
				  $$.targetRegister = newReg;
				  emit(NOLABEL, MULT, $1.targetRegister, $3.targetRegister, newReg);}

        | exp AND exp		{  int newReg = NextRegister();
				  if (! (($1.type == TYPE_BOOL) && ($3.type == TYPE_BOOL))){
				     printf("\n***Error: types of operands for operation AND do not match\n");
				  } 
				  $$.type = TYPE_BOOL;
				  $$.targetRegister = newReg;
				  emit(NOLABEL, AND_INSTR, $1.targetRegister, $3.targetRegister, newReg);} 


        | exp OR exp       	{ int newReg = NextRegister();
				  if (! (($1.type == TYPE_BOOL) && ($3.type == TYPE_BOOL))){
				     printf("\n***Error: types of operands for operation OR do not match\n");
				  } 
				  $$.type = TYPE_BOOL;
				  $$.targetRegister = newReg;
				  emit(NOLABEL, OR_INSTR, $1.targetRegister, $3.targetRegister, newReg); }


        | ID			{ /* BOGUS  - needs to be fixed */
	                          int newReg = NextRegister();
				  char *name = $1.str;
				  SymTabEntry *entry = lookup(name);
				  if (entry == NULL){
					printf("\n***Error: Variable %s not declared\n", name);
				  }
				  else {
	                         	 $$.targetRegister = newReg;
				 	 emit(NOLABEL, LOADAI, 0, entry->offset, newReg);
                                 	 $$.type = entry->type;
				  }
	                        }

        | ID '[' exp ']'	{ if (!($3.type == TYPE_INT)){
					printf("\n***Error: subscript exp not integer\n");
				  }
				  char *name = $1.str;
				  SymTabEntry *entry = lookup(name);
				  if (entry == NULL){
				  	printf("\n***Error: undeclared identifier %s\n", name);
				  }
				  else {
				 	 if (entry->array != 1){
						printf("\n***Error: id %s is not an array\n", name);
				 	 }
				 	 int newReg = NextRegister();
				 	 int targetRegister = $3.targetRegister;
				 	 int newReg2 = NextRegister();
				 	 emit(NOLABEL, LOADI, entry->offset, newReg, EMPTY);
					  int newReg3 = NextRegister();
				 	 emit(NOLABEL, LOADI, 4, newReg2, EMPTY);
				 	 emit(NOLABEL, MULT, targetRegister, newReg2, newReg3);
				 	 int newReg4 = NextRegister();
				 	 emit(NOLABEL, ADD, newReg, newReg3, newReg4);
				 	 int newReg5 = NextRegister();
				 	 emit(NOLABEL, LOADAO, 0, newReg4, newReg5);
				 	 $$.targetRegister = newReg5;
				 	 $$.type = entry->type;
				}
				}
 


	| ICONST                 { int newReg = NextRegister();
	                           $$.targetRegister = newReg;
				   $$.type = TYPE_INT;
				   emit(NOLABEL, LOADI, $1.num, newReg, EMPTY); }

        | TRUE                   { int newReg = NextRegister(); /* TRUE is encoded as value '1' */
	                           $$.targetRegister = newReg;
				   $$.type = TYPE_BOOL;
				   emit(NOLABEL, LOADI, 1, newReg, EMPTY); }

        | FALSE                   { int newReg = NextRegister(); /* TRUE is encoded as value '0' */
	                           $$.targetRegister = newReg;
				   $$.type = TYPE_BOOL;
				   emit(NOLABEL, LOADI, 0, newReg, EMPTY); }

	| error { yyerror("***Error: illegal expression\n");}  
	;


ctrlexp	: ID ASG ICONST ',' ICONST { if ($3.num > $5.num){
					printf("\n***Error: lower bound exceeds upper bound\n");
				    }
				    int newReg1 = NextRegister();
				    int newReg2 = NextRegister();
				    int label = NextLabel();
				    $$.targetRegister = newReg1;
				    $$.name = $1.str;
				    emit(NOLABEL, LOADI, $3.num, newReg1, EMPTY);
				    SymTabEntry *entry = lookup($1.str);
				    if (entry == NULL){
				  	printf("\n***Error: undeclared identifier %s\n", $1.str);
				    }
				    else {
				   	   if (entry->array == 1){
						printf("\n***Error: induction variable not scalar integer variable\n");
					    }
					    emit(NOLABEL, STOREAI, newReg1, 0, entry->offset);
					    emit(NOLABEL, LOADI, $5.num, newReg2, EMPTY);
				    }
				    }
        ;

condexp	: exp NEQ exp		{ 
				  if (!(($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
    				    printf("\n***Error: types of operands for operation != do not match\n");
                                  }
				  int newReg = NextRegister();
				  $$.targetRegister = newReg;
				  $$.type = TYPE_BOOL;
				  emit(NOLABEL, CMPNE, $1.targetRegister, $3.targetRegister, newReg);
				} 

        | exp EQ exp		{ 
				  if (!(($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
    				    printf("\n***Error: types of operands for operation == do not match\n");
                                  }
				  int newReg = NextRegister();
				  $$.targetRegister = newReg;
				  $$.type = TYPE_BOOL;
				  emit(NOLABEL, CMPEQ, $1.targetRegister, $3.targetRegister, newReg);
				 } 

        | exp LT exp		{ 
				  if (!(($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
    				    printf("\n***Error: types of operands for operation < do not match\n");
                                  }
				  int newReg = NextRegister();
				  $$.targetRegister = newReg;
				  $$.type = TYPE_BOOL;
				  emit(NOLABEL, CMPLT, $1.targetRegister, $3.targetRegister, newReg);
				}

        | exp LEQ exp		{
				  if (!(($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
    				    printf("\n***Error: types of operands for operation <= do not match\n");
                                  }
				  int newReg = NextRegister();
				  $$.targetRegister = newReg;
				  $$.type = TYPE_BOOL;
				  emit(NOLABEL, CMPLE, $1.targetRegister, $3.targetRegister, newReg);
				}

	| exp GT exp		{  
				  if (!(($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
    				    printf("\n***Error: types of operands for operation > do not match\n");
                                  }
				  int newReg = NextRegister();
				  $$.targetRegister = newReg;
				  $$.type = TYPE_BOOL;
				  emit(NOLABEL, CMPGT, $1.targetRegister, $3.targetRegister, newReg);
				 }

	| exp GEQ exp		{ 
				  if (!(($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
    				    printf("\n***Error: types of operands for operation >= do not match\n");
                                  }
				  int newReg = NextRegister();
				  $$.targetRegister = newReg;
				  $$.type = TYPE_BOOL;
				  emit(NOLABEL, CMPGE, $1.targetRegister, $3.targetRegister, newReg);
				  }

	| error { yyerror("***Error: illegal conditional expression\n");}  
        ;

%%

void yyerror(char* s) {
        fprintf(stderr,"%s\n",s);
        }


int
main(int argc, char* argv[]) {

  printf("\n     CS415 Spring 2022 Compiler\n\n");

  outfile = fopen("iloc.out", "w");
  if (outfile == NULL) { 
    printf("ERROR: Cannot open output file \"iloc.out\".\n");
    return -1;
  }

  CommentBuffer = (char *) malloc(1961);  
  InitSymbolTable();

  printf("1\t");
  yyparse();
  printf("\n");

  PrintSymbolTable();
  
  fclose(outfile);
  
  return 1;
}




