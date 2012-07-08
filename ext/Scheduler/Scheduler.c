#include "ruby.h"
#include <stdlib.h>
#include <stdio.h>

#define SLOT_WEIGHT_INITIAL_VAL -1.0

// bundle exec rake install
// irb -rubygems
// require 'Scheduler'
// include Scheduler
//
static int debug = 0;

typedef struct _node_t node_t;

struct _node_t {
  int person_id; // numerical id of person
  float weight;  // scheduling weight
};

typedef struct _solution_t solution_t;

struct _solution_t {
  int active;              // whether or this branch is being considered.
  float total_weight;      // solution weight.
  int total_depth;         // depth into the solution (0 to num_slots).
  int total_children;      // # of children in chilren array.
  int *used_person_id_map; // bitmap of locked person_ids in the node_list.
  node_t *node_list;       // array of solution nodes for this solution.
  solution_t *parent;      // each solution branch will have 0 or 1 parent.
  solution_t *children;    // each solution branch may have many children.
};

typedef struct _schedule_t schedule_t;

struct _schedule_t {
  int num_people;  // # of people being considered
  int num_slots;   // # of scheduling slots to be filled
  float **weights; // schedule weight grid
};

static schedule_t *sched = NULL;
static int num_expanded_solutions = 0;
static solution_t *incumbent_solution = NULL;
static float incumbent_value = SLOT_WEIGHT_INITIAL_VAL;

int fact(int n);
void print_solution(node_t *nodes, int number_of_slots);
int solution_is_feasible(solution_t *s);
int solution_is_active(solution_t *s);
float max_cost_for_slot(int slot_id, int* constraint_map, int *person_id);
void update_incumbent_and_branch(solution_t *s);
int create_root(solution_t **root);
int create_branch(solution_t *root, int depth);
int select_branch(solution_t *branch, solution_t **new_root);
int prune_branch(solution_t *branch);
int expand_branch(solution_t *root, int depth);
int free_branch(solution_t *root);

#define safe_free(var)  \
  do {                  \
    if (var) {          \
      free(var);        \
      var = NULL;       \
    }                   \
  } while(0)

int
fact(int n)
{
  int result = 1;
  for(int i = 1; i <= n ; i++)
    result = result * i;
  return result;
}

void
print_solution(node_t *nodes, int number_of_slots)
{
  float w = 0.0;

  for(int i = 0; i < number_of_slots; i++) {
    printf("%d => %1.3f ",
	   nodes->person_id, nodes->weight);
    w += nodes->weight;
    nodes++;
  }

  printf(" total weight: %1.3f\n", w);
}

int
solution_is_feasible(solution_t *s)
{
  int p = 0;
  int count = 0;
  int ret_val = 0;
  int *map = calloc(sched->num_people, sizeof(int));

  // check the bitmap to see if num_slots unique values are assigned.
  // Note that this needs to take into account non-complete, active
  // solutions that just 'happen' to have all unique values
  //
  for (int i = 0; i < sched->num_slots; i++) {
    p = s->node_list[i].person_id;

    if (map[p] == 0) {
      map[p] = 1;
      count++;
    }
  }

  if (count == sched->num_slots) {
    ret_val = 1;
  }

  safe_free(map);
  return ret_val;
}

int
solution_is_active(solution_t *s)
{
  int i = 0;
  int ret_val = 0;

  while (ret_val == 0 && i < s->total_children) {
    ret_val = s->children[i++].active;
  }

  return ret_val;
}

float
max_cost_for_slot(int slot_id, int* constraint_map, int *person_id)
{
  float max = SLOT_WEIGHT_INITIAL_VAL;
  *person_id = -1;

  for (int i = 0; i < sched->num_people; i++) {
    if ((sched->weights[i][slot_id] > max) && (constraint_map[i] == 0)) {
      max = sched->weights[i][slot_id];
      *person_id = i;
    }
  }

  return max;
}

void
update_incumbent_and_branch(solution_t *s)
{
  int updated = 0;

  // update incumbent if the new solution is better
  //
  if (s->total_weight > incumbent_value) {
    incumbent_solution = s;
    incumbent_value = s->total_weight;
    updated = 1;
  }

  if (updated && debug) {
    printf("%s: new incumbent, weight %1.3f, at depth %d\n",
	   __FUNCTION__, incumbent_value, incumbent_solution->total_depth);
  }

  // we are done with this branch
  //
  prune_branch(s);
}

int
create_root(solution_t **root)
{
  int id = 0;
  float weight = 0;
  int people = sched->num_people;
  int slots = sched->num_slots;

  // allocate the new root
  //
  *root = calloc(1, sizeof(solution_t));

  // set the attributes
  //
  (*root)->active = 1;
  (*root)->total_weight = 0;
  (*root)->total_depth = 0;
  (*root)->total_children = 0;
  (*root)->used_person_id_map = calloc(people, sizeof(int));
  (*root)->node_list = calloc(slots, sizeof(node_t));
  (*root)->parent = NULL;
  (*root)->children = malloc(sizeof(solution_t) * people);

  // fill in the root solution set
  //
  for (int i = 0; i < slots; i++) {
    weight = max_cost_for_slot(i, (*root)->used_person_id_map, &id);
    (*root)->node_list[i].person_id = id;
    (*root)->node_list[i].weight = weight;
    (*root)->total_weight += weight;
  }

  return 0;
}

int
create_branch(solution_t *root, int depth)
{
  // make a new branch for each person_id based on the current depth
  // and fill in 'randomly' with best-in-slot values for the remaining
  // slots
  //
  int people = sched->num_people;
  int slots = sched->num_slots;
  solution_t *s;

  for (int i = 0; i < people; i++) {

    if (root->used_person_id_map[i] == 1) {
      continue;
    }

    // add the new child root to its parent
    //
    root->total_children += 1;
    s = &(root->children[i]);

    // set the attributes
    //
    s->active = 1;
    s->total_weight = 0;
    s->total_depth = depth + 1;
    s->total_children = 0;
    s->used_person_id_map = calloc(people, sizeof(int));
    s->node_list = calloc(slots, sizeof(node_t));
    s->parent = root;
    s->children = calloc(people, sizeof(solution_t));

    // copy previously locked slots (if any)
    //
    for (int j = 0; j < depth; j++) {
      s->node_list[j].person_id = root->node_list[j].person_id;
      s->node_list[j].weight = root->node_list[j].weight;
      s->total_weight += root->node_list[j].weight;
      s->used_person_id_map[root->node_list[j].person_id] = 1;
    }

    // set node for current slot
    //
    s->node_list[depth].person_id = i;
    s->node_list[depth].weight = sched->weights[i][0];
    s->total_weight += sched->weights[i][0];
    s->used_person_id_map[i] = 1;

    // fill in remaining slots
    //
    for (int j = depth + 1; j < slots; j++) {
      int id;
      float weight = max_cost_for_slot(j, s->used_person_id_map, &id);
      s->node_list[j].person_id = id;
      s->node_list[j].weight = weight;
      s->total_weight += weight;
    }

    // don't even bother with this solution if we already know it cannot
    // produce a better result
    //
    if (s->total_weight < incumbent_value) {
      s->active = 0;
    }

    if (debug) {
      printf("%s: index: %d, active: %s, ",
	     __FUNCTION__, i, s->active ? "true" : "false");
      print_solution(s->node_list, slots);
    }
  }

  return 0;
}

int
select_branch(solution_t *branch, solution_t **new_root)
{
  int ret_val = 0;
  int index = 0;
  float weight = SLOT_WEIGHT_INITIAL_VAL;
  solution_t *p = NULL;

  p = branch;
  *new_root = NULL;

  while (p->active == 0 && p->total_depth > 0) {
    // find the nearest active root
    //
    p = p->parent;
  }

  if(p) {
    // walk the children and find the solution with the highest weight
    //
    for (int i = 0; i < p->total_children; i++) {
      if (p->children[i].active == 1 &&
	  p->children[i].total_weight > weight &&
	  p->children[i].total_weight > incumbent_value) {
	weight = p->children[i].total_weight;
	index = i;
	*new_root = &(p->children[index]);
      }
    }
  }

  if (*new_root) {
    if (debug) {
      printf("%s: depth: %d, index: %d, weight: %1.3f\n",
	     __FUNCTION__, (*new_root)->total_depth, index, weight);
    }
    ret_val = 1;
  } else {
    *new_root = NULL;
    ret_val = 0;
  }

  return ret_val;
}

int
prune_branch(solution_t *branch)
{
  if (branch) {
    for (int i = 0; i < branch->total_children; i++) {
      branch->children[i].active = 0;
    }
    branch->active = 0;

    if (debug) {
      printf("%s: depth %d, weight %1.3f\n",
	     __FUNCTION__, branch->total_depth, branch->total_weight);
    }
  }
  return 0;
}

int
expand_branch(solution_t *root, int depth)
{
  int slots = sched->num_slots;
  solution_t *new_root = NULL;

  num_expanded_solutions++;

  if (depth == slots) {
    return 0;
  }

  if (root->active == 0) {
    return 0;
  }

  if (debug) {
    printf("%s: new depth: %d, weight %1.3f\n",
	   __FUNCTION__, depth+1, root->total_weight);
  }

  create_branch(root, depth);

  // iterate on the branch as long as it is active
  //
  while(root->active) {

    if (!select_branch(root, &new_root) || !new_root) {
      root->active = 0;
      break;
    }

    if (solution_is_feasible(new_root)) {
      update_incumbent_and_branch(new_root);
    }

    if (new_root->active) {
      expand_branch(new_root, depth+1);
    }

    if (!solution_is_active(root)) {
      root->active = 0;
    }
  }

  return 0;
}

int
free_branch(solution_t *root)
{
  int i = 0;

  // walk the contents of the tree/branch and free all data structures
  //
  while (i < root->total_children) {
    free_branch(&(root->children[i]));

    if (debug) {
      printf("%s: freed branch, depth %d, child %d\n",
	     __FUNCTION__, root->total_depth, i);
    }

    i++;
  }

  safe_free(root->used_person_id_map);
  safe_free(root->node_list);
  safe_free(root->children);

  return 0;
}


/*----------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------*/


// Defining a space for information and references about the module to
// be stored internally
//
VALUE cScheduler = Qnil;

// Prototype for the initialization method - Ruby calls this, not you
//
void Init_Scheduler();

// schedule methods
//
VALUE method_schedule_create(VALUE self, VALUE number_of_slots);
VALUE method_schedule_free(VALUE self);
VALUE method_schedule_set_weight(VALUE self, VALUE weights);
VALUE method_schedule_compute_solution(VALUE self);

// The initialization method for this module
//
void Init_Scheduler() {
  cScheduler = rb_define_module("Scheduler");
  rb_define_method(cScheduler, "schedule_create", method_schedule_create, 1);
  rb_define_method(cScheduler, "schedule_free", method_schedule_free, 0);
  rb_define_method(cScheduler, "schedule_set_weight", method_schedule_set_weight, 1);
  rb_define_method(cScheduler, "schedule_compute_solution", method_schedule_compute_solution, 0);
}

VALUE method_schedule_create(VALUE self, VALUE number_of_slots) {
  Check_Type(number_of_slots, T_FIXNUM);
  sched = calloc(1, sizeof(schedule_t));
  sched->num_people = 0;
  sched->num_slots = NUM2INT(number_of_slots);
  sched->weights = NULL;
  return Qnil;
}

VALUE method_schedule_free(VALUE self)
{
  if (sched) {
    for (int i = 0; i < sched->num_people; i++) {
      safe_free(sched->weights[i]);
    }
    safe_free(sched->weights);
    safe_free(sched);
  }
  return Qnil;
}

VALUE method_schedule_set_weight(VALUE self, VALUE weights)
{
  int index = 0;

  Check_Type(weights, T_ARRAY);

  if (sched) {

    if (RARRAY_LEN(weights) != sched->num_slots) {
      return Qfalse;
    }

    index = sched->num_people;

    sched->num_people += 1;

    sched->weights =
      realloc(sched->weights, sched->num_people * sizeof(sched->weights));
    sched->weights[index] = calloc(sched->num_slots, sizeof(float));

    for (int i = 0; i < sched->num_slots; i++) {
      (sched->weights)[index][i] = NUM2DBL((RARRAY_PTR(weights))[i]);
      if (debug) {
        printf("Added weight %1.3f\n", (sched->weights)[index][i]);
      }
    }

    return Qtrue;
  }

  return Qfalse;
}

VALUE method_schedule_compute_solution(VALUE self)
{
  solution_t *root = NULL;

  int people = sched->num_people;
  int slots = sched->num_slots;

  // nPk = n!/(n-k)!
  //
  int total_possible_solutions = fact(people) / fact(people - slots);

  // initialize the bb proces
  //
  num_expanded_solutions = 0;
  incumbent_value = SLOT_WEIGHT_INITIAL_VAL;
  incumbent_solution = NULL;
  create_root(&root);

  // run the branching algorithm
  //
  expand_branch(root, 0);

  if (debug) {
    printf("=================================================================\n");
    printf("%s: best solution is: ", __FUNCTION__);
    print_solution(incumbent_solution->node_list, slots);
    printf("%s: checked %d of %d total solutions\n",
           __FUNCTION__, num_expanded_solutions, total_possible_solutions);
    printf("=================================================================\n");
  }

  // prepare the solution array of people, in order by slot
  //
  VALUE arr;
  arr = rb_ary_new();
  for (int i = 0; i < slots; i++) {
    rb_ary_push(arr, INT2NUM(incumbent_solution->node_list[i].person_id));
  }

  // cleanup
  //
  free_branch(root);
  safe_free(root);

  // return the best result array
  //
  return arr;
}
