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

// Structure pour passer des infos à chaque thread
typedef struct {
    int id;
    char action[32];
} ThreadData;

void* thread_task(void* arg) {
    ThreadData* data = (ThreadData*)arg;
    printf("[THREAD] Tâche %d démarrée : %s\n", data->id, data->action);

    // Exécution réelle selon l'action
    if (strcmp(data->action, "generate_tests") == 0) {
        system("bash templates/modules/generate_tests.sh python true false github");
    } else if (strcmp(data->action, "generate_deploy") == 0) {
        system("bash templates/modules/deploy_config.sh python dev,staging github");
    } else {
        printf("[THREAD] Action inconnue.\n");
    }

    printf("[THREAD] Tâche %d terminée : %s\n", data->id, data->action);
    return NULL;
}

void execute_threads(int count) {
    pthread_t threads[count];
    ThreadData datas[count];

    // Exemple : 2 threads avec des actions différentes
    for (int i = 0; i < count; i++) {
        datas[i].id = i + 1;
        if (i == 0)
            strcpy(datas[i].action, "generate_tests");
        else
            strcpy(datas[i].action, "generate_deploy");
        pthread_create(&threads[i], NULL, thread_task, &datas[i]);
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
