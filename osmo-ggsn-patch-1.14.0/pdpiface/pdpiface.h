#pragma once

struct pdp_t;

struct pdpData {
	const char* ip_addr;
	const char* msisdn;
};

int sendPDPData(struct pdp_t* pdp, int operation);
