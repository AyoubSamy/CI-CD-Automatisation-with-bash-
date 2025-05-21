/*
 * process_handler.c - Gestionnaire de processus pour fork/thread
 * Ce module est appelé par cicdgen.sh via l'option -f (fork) ou -t (thread)
 * Il exécute des traitements parallèles simulés pour démonstration.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/wait.h>
#include <string.h>

// ======== THREAD MODE ========
void* thread_task(void* arg) {
    int id = *((int*)arg);
    printf("[THREAD] Tâche %d démarrée.\n", id);
    sleep(2); // Simulation d'une tâche
    printf("[THREAD] Tâche %d terminée.\n", id);
    return NULL;
}

void execute_threads(int count) {
    pthread_t threads[count];
    int ids[count];
    for (int i = 0; i < count; i++) {
        ids[i] = i + 1;
        pthread_create(&threads[i], NULL, thread_task, &ids[i]);
    }
    for (int i = 0; i < count; i++) {
        pthread_join(threads[i], NULL);
    }
}

// ======== FORK MODE ========
void execute_forks(int count) {
    for (int i = 0; i < count; i++) {
        pid_t pid = fork();
        if (pid == 0) {
            printf("[FORK] Processus fils %d démarré (PID: %d)\n", i + 1, getpid());
            sleep(2); // Simulation d'une tâche
            printf("[FORK] Processus fils %d terminé (PID: %d)\n", i + 1, getpid());
            exit(0);
        }
    }
    // Attente de tous les fils
    while (wait(NULL) > 0);
}

// ======== MAIN ========
int main(int argc, char* argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s [-f|-t] <nombre_de_tâches>\n", argv[0]);
        return 1;
    }

    int count = atoi(argv[2]);

    if (count <= 0) {
        fprintf(stderr, "Le nombre de tâches doit être supérieur à zéro.\n");
        return 2;
    }

    if (strcmp(argv[1], "-f") == 0) {
        execute_forks(count);
    } else if (strcmp(argv[1], "-t") == 0) {
        execute_threads(count);
    } else {
        fprintf(stderr, "Option invalide : utilisez -f (fork) ou -t (thread).\n");
        return 3;
    }

    return 0;
}
