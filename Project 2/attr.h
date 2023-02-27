/**********************************************
        CS415  Project 2
        Spring  2022
        Student Version
**********************************************/

#ifndef ATTR_H
#define ATTR_H

typedef union {int num; char *str;} tokentype;

typedef enum type_expression {TYPE_INT=0, TYPE_BOOL, TYPE_ERROR} Type_Expression;

typedef struct {
        Type_Expression type;
        int targetRegister;
	int num;
	char *name;
	int label1;
	int label2;
	int label3;
        } regInfo;

typedef struct {
	Type_Expression type;
	int array;
	int array_size;
	} varType;

typedef struct var_node{
	char *name;
	int array;
	struct var_node *next;
} varNode;

typedef struct {
	varNode *head;
} variableLinkedList;

typedef struct {
	int label1;
	int label2;
	int label3;
} conditionalInfo;

typedef struct {
	int target;
} statementInfo;
#endif


  
