/*
 *********************************************
 *  415 Compilers                            *
 *  Spring 2022                              *
 *  Students                                 *
 *********************************************
 */


#include <stdarg.h>
#include <stdlib.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include "Instr.h"
#include "InstrUtils.h"


int main(int argc, char *argv[])
{
        Instruction *InstrList = NULL;
	
	if (argc != 1) {
  	    fprintf(stderr, "Use of command:\n  deadcode  < ILOC file\n");
		exit(-1);
	}

	fprintf(stderr,"------------------------------------------------\n");
	fprintf(stderr,"        Local Deadcode Elimination\n               415 Compilers\n                Spring 2022\n");
	fprintf(stderr,"------------------------------------------------\n");

        InstrList = ReadInstructionList(stdin);
 
        /* HERE IS WHERE YOUR CODE GOES */

	Instruction *current_node = InstrList;
	int counter = 0;
	order_node *head_register = NULL;
	while (current_node != NULL){
		current_node->critical = 0;
		current_node->order = counter;
		counter++;
		current_node = current_node->next;
	}
	current_node = LastInstruction(InstrList);
	while (current_node->opcode != OUTPUTAI){
		current_node = current_node->prev;
	}
	order_node *output_nodes = NULL;
	Instruction *traverse = current_node->prev;
	while (traverse != NULL){
		if (traverse->opcode == OUTPUTAI){
			order_node *new_node = (order_node *)malloc(sizeof(order_node));
			new_node->order = traverse->order;
			if (output_nodes == NULL){
				output_nodes = new_node;
			}
			else {
				order_node *current_order = output_nodes;
				while (current_order->next != NULL){
					current_order = current_order->next;
				}
				current_order->next = new_node;
			}
		}
		traverse = traverse->prev;
	}
	InstrList->critical = 1;
	while (current_node != NULL){
		current_node->critical = 1;
		if (current_node->opcode == OUTPUTAI){
			Instruction *other_node = current_node->prev;
			while (other_node != NULL){
				if (other_node->opcode == STOREAI && (other_node->field2 == current_node->field1 && other_node->field3 == current_node->field2)){
					break;
				}
				other_node = other_node->prev;
			}
			current_node = other_node;
		}
		else if (current_node->opcode == ADD || (current_node->opcode == SUB || current_node->opcode == MUL)){
			Instruction *other_node = current_node->prev;
			while (other_node != NULL){
				if (other_node->opcode != STOREAI && other_node->opcode != OUTPUTAI){
					if (other_node->opcode == LOADI){
						if (other_node->field2 == current_node->field1){
							order_node *new_node = (order_node *)malloc(sizeof(order_node));
							new_node->order = other_node->order;
							if (head_register == NULL){
								head_register = new_node;
							} else {
								int found = 0;
								order_node *start = head_register;
								while (start->next != NULL){
									if (start->order == new_node->order){
										found = 1;
										break;
									}
									start = start->next;
								}
								if (found == 0){
									start->next = new_node;
								}
							}
							break;
						}
					} else {
						if (other_node->field3 == current_node->field1){
							order_node *new_node = (order_node *)malloc(sizeof(order_node));
							new_node->order = other_node->order;
							if (head_register == NULL){
								head_register = new_node;
							} else {
								int found = 0;
								order_node *start = head_register;
								while (start->next != NULL){
									if (start->order == new_node->order){
										found = 1;
										break;
									}
									start = start->next;
								}
								if (found == 0){
									start->next = new_node;
								}
							}
							break;
						}
					}
				}
				other_node = other_node->prev;
			}
			other_node = current_node->prev;
			while (other_node != NULL){
				if (other_node->opcode != STOREAI && other_node->opcode != OUTPUTAI){
					if (other_node->opcode == LOADI){
						if (other_node->field2 == current_node->field2){
							current_node = other_node;
							break;
						}
					} else {
						if (other_node->field3 == current_node->field2){
							current_node = other_node;
							break;
						}
					}
				}
				other_node = other_node->prev;
			}
		}
		else if (current_node->opcode == LOADI){
			if (head_register == NULL){
				if (output_nodes == NULL){
					break;
				}
				else {
					current_node = InstrList;
					while (current_node->order != output_nodes->order){
						current_node = current_node->next;
					}
					order_node *temp = output_nodes;
					output_nodes = output_nodes->next;
					free(temp);
				}
			} else {
				current_node = InstrList;
				while (current_node->order != head_register->order){
					current_node = current_node->next;
				}
				order_node *temp = head_register;
				head_register = head_register->next;
				free(temp);
			}
		}
		else if (current_node->opcode == STOREAI){
			Instruction *other_node = current_node->prev;
			while (other_node != NULL){
				if (other_node->opcode == ADD || (other_node->opcode == SUB || other_node->opcode == MUL)){
					if (other_node->field3 == current_node->field1){
						current_node = other_node;
						break;
					}
				} else if (other_node->opcode == LOADI){
					if (other_node->field2 == current_node->field1){
						current_node = other_node;
						break;
					}
				} else if (other_node->opcode == LOADAI){
					if (other_node->field3 == current_node->field1){
						current_node = other_node;
						break;
					}
				}
				other_node = other_node->prev;
			}
		}
		else if (current_node->opcode == LOADAI){
			Instruction *other_node = current_node->prev;
			while (other_node != NULL){
				if (other_node->opcode == STOREAI){
					if (other_node->field2 == current_node->field1 && other_node->field3 == current_node->field2){
						current_node = other_node;
						break;
					}
				}
				other_node = other_node->prev;
			}
		}
	}
	current_node = InstrList;
	while (current_node != NULL){
		if (current_node->critical == 0){
			Instruction *temp = current_node;
			current_node->prev->next = current_node->next;
			current_node->next->prev = current_node->prev;
			current_node = current_node->next;
			free(temp);
		}
		else {
			current_node = current_node->next;
		}
	}	
        PrintInstructionList(stdout, InstrList);

	fprintf(stderr,"\n-----------------DONE---------------------------\n");
	
	return 0;
}
