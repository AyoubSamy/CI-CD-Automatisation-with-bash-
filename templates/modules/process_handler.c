#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <sys/wait.h>

/**
 * Structure pour passer des arguments aux threads
 */
typedef struct {
    char **command;
    int command_length;
} thread_args;

/**
 * Fonction: thread_function
 * Description: Fonction exécutée par le thread
 * Paramètres:
 *   arg: Arguments du thread (commande à exécuter)
 */
void *thread_function(void *arg) {
    thread_args *args = (thread_args *)arg;
    
    // Exécution de la commande
    pid_t pid = fork();
    
    if (pid == 0) {
        // Processus fils
        execvp(args->command[0], args->command);
        perror("Erreur lors de l'exécution de la commande");
        exit(EXIT_FAILURE);
    } else if (pid > 0) {
        // Processus parent
        int status;
        waitpid(pid, &status, 0);
    } else {
        // Erreur
        perror("Fork failed");
        exit(EXIT_FAILURE);
    }
    
    return NULL;
}

/**
 * Fonction: execute_fork_mode
 * Description: Exécute une commande en utilisant le fork
 * Paramètres:
 *   command: Commande à exécuter
 */
void execute_fork_mode(char **command) {
    pid_t pid = fork();
    
    if (pid == 0) {
        // Processus fils
        execvp(command[0], command);
        perror("Erreur lors de l'exécution de la commande");
        exit(EXIT_FAILURE);
    } else if (pid > 0) {
        // Processus parent
        int status;
        waitpid(pid, &status, 0);
    } else {
        // Erreur
        perror("Fork failed");
        exit(EXIT_FAILURE);
    }
}

/**
 * Fonction: execute_thread_mode
 * Description: Exécute une commande en utilisant des threads
 * Paramètres:
 *   command: Commande à exécuter
 */
void execute_thread_mode(char **command) {
    pthread_t thread;
    thread_args args;
    
    args.command = command;
    args.command_length = 0;
    while (command[args.command_length] != NULL) {
        args.command_length++;
    }
    
    if (pthread_create(&thread, NULL, thread_function, &args) != 0) {
        perror("Erreur lors de la création du thread");
        exit(EXIT_FAILURE);
    }
    
    if (pthread_join(thread, NULL) != 0) {
        perror("Erreur lors de l'attente du thread");
        exit(EXIT_FAILURE);
    }
}

/**
 * Fonction principale
 */
int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s --mode=<fork|thread> command [args...]\n", argv[0]);
        return EXIT_FAILURE;
    }
    
    char **command = &argv[2];
    
    if (strcmp(argv[1], "--mode=fork") == 0) {
        execute_fork_mode(command);
    } else if (strcmp(argv[1], "--mode=thread") == 0) {
        execute_thread_mode(command);
    } else {
        fprintf(stderr, "Mode inconnu: %s\n", argv[1]);
        return EXIT_FAILURE;
    }
    
    return EXIT_SUCCESS;
}