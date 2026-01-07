#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <pthread.h>
#include "pdpiface.h"

#include <osmocom/gsm/gsm48_ie.h>
#include <osmocom/gsm/protocol/gsm_04_08_gprs.h>
#include <osmocom/gtp/gtp.h>
#include <osmocom/gtp/pdp.h>
#include "../lib/util.h"
#include "../lib/in46_addr.h"
#include "../lib/ippool.h"
#include "../gtp/gtp_internal.h"

#define PORT 8081

const char* formatPDP(struct pdpData* pdp, int operation) {
	int bufferLen = (7 + strlen(pdp->ip_addr) + strlen(pdp->msisdn) + 2 + 1); //7: 'pdp_add'/'pdp_rem', plus two commas & null terminator
	char* buffer = malloc(bufferLen);
	snprintf(buffer, bufferLen, "pdp_%s,%s,%s", ((operation == 0) ? "add" : "del"), pdp->ip_addr, pdp->msisdn);
	return (const char*)buffer;
}

void extractPDPDat(struct pdpData* pdp, struct pdp_t* pdp_d) {
	struct ippoolm_t *peer4;
	char name_buf[256];
	int rc;
	
	peer4 = pdp_get_peer_ipv(pdp_d, 0);
	const char* ip = in46a_ntop(&peer4->addr, name_buf, sizeof(name_buf));
	pdp->ip_addr = malloc(strlen(ip) + 1);
	if(pdp->ip_addr == NULL) {
		printf("Error extracting PDP Data: malloc failed!\n");
		return;
	}
	strcpy((char*)pdp->ip_addr, ip);
	rc = gsm48_decode_bcd_number2(name_buf, sizeof(name_buf), 
		pdp_d->msisdn.v, pdp_d->msisdn.l, 0);
	const char* msisdn = rc ? "(NONE)" : name_buf;
	pdp->msisdn = malloc(strlen(msisdn) + 1);
	if(pdp->msisdn == NULL) {
		printf("Error extracting PDP Data: malloc failed!\n");
		return;
	}
	strcpy((char*)pdp->msisdn, msisdn);
}

int sendPDPData(struct pdp_t* pdp, int operation) {
    int client_fd;
    struct sockaddr_in serv_addr;
    const char* pdpMessage;
	socklen_t addrlen = sizeof(serv_addr);
	struct pdpData pdpDat;
	extractPDPDat(&pdpDat, pdp);
	pdpMessage = formatPDP(&pdpDat, operation);
    if ((client_fd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        printf("\n Socket creation error \n");
		return -1;
    }

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT);

    if (inet_pton(AF_INET, "172.20.0.18", &serv_addr.sin_addr)
        <= 0) {
        printf(
            "\nInvalid address/ Address not supported \n");
        return -1;
    }
	
	sendto(client_fd, pdpMessage, strlen(pdpMessage), 0,
					 (struct sockaddr *)&serv_addr, addrlen);
    printf("PDP Data sent to Server\n");
	free((void*)pdpDat.ip_addr);
	free((void*)pdpDat.msisdn);
    close(client_fd);
	return 0;
}