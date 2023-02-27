/*
 *********************************************
 *  415 Compilers                            *
 *  Spring 2022                              *
 *  Students                                 *
 *********************************************
 */

#ifndef INSTR_H
#define INSTR_H

typedef enum {LOADI, LOAD, LOADAI, LOADAO, STORE, STOREAI, STOREAO, ADD, SUB, MUL, DIV, LSHIFTI, RSHIFTI, OUTPUTAI} OpCode;

typedef struct InstructionInfo Instruction;

struct InstructionInfo {
	OpCode opcode;
	int field1;
	int field2;
	int field3;
	int critical;
	int order;
	Instruction *prev;	/* previous instruction */
	Instruction *next;	/* next instruction */
};

typedef struct order_info order_node;

struct order_info {
	int order;
	order_node *next;
};

#endif
