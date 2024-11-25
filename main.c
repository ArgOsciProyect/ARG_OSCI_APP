#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <esp_wifi.h>
#include <esp_event.h>
#include <esp_log.h>
#include <nvs_flash.h>
#include <lwip/sockets.h>
#include <esp_http_server.h>
#include <cJSON.h>

#define WIFI_SSID "ESP32_AP"
#define WIFI_PASSWORD "password123"
#define MAX_STA_CONN 4
#define PORT 8080

static const char *TAG = "ESP32_AP";

void wifi_init() {

    esp_netif_create_default_wifi_ap();
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    wifi_config_t wifi_config = {
        .ap = {
            .ssid = WIFI_SSID,
            .ssid_len = strlen(WIFI_SSID),
            .password = WIFI_PASSWORD,
            .max_connection = MAX_STA_CONN,
            .authmode = WIFI_AUTH_WPA_WPA2_PSK
        },
    };

    if (strlen(WIFI_PASSWORD) == 0) {
        wifi_config.ap.authmode = WIFI_AUTH_OPEN;
    }

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_APSTA));
    ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
}



esp_err_t scan_wifi_handler(httpd_req_t *req) {
    ESP_LOGI(TAG, "Scanning Wi-Fi networks");
    wifi_scan_config_t scan_config = {
        .ssid = NULL,
        .bssid = NULL,
        .channel = 0,
        .show_hidden = true
    };
    ESP_ERROR_CHECK(esp_wifi_scan_start(&scan_config, true));
    uint16_t num_networks = 0;
    ESP_ERROR_CHECK(esp_wifi_scan_get_ap_num(&num_networks));
    wifi_ap_record_t *ap_records = malloc(sizeof(wifi_ap_record_t) * num_networks);
    ESP_ERROR_CHECK(esp_wifi_scan_get_ap_records(&num_networks, ap_records));
    cJSON *root = cJSON_CreateArray();
    for (int i = 0; i < num_networks; i++) {
        cJSON *item = cJSON_CreateObject();
        cJSON_AddStringToObject(item, "SSID", (char *)ap_records[i].ssid);
        cJSON_AddItemToArray(root, item);
    }
    const char *json_response = cJSON_Print(root);
    httpd_resp_send(req, json_response, strlen(json_response));
    free(ap_records);
    cJSON_Delete(root);
    free((void *)json_response);
    return ESP_OK;
}

esp_err_t connect_wifi_handler(httpd_req_t *req) {
    ESP_LOGI(TAG, "Connecting to Wi-Fi network");
    char content[100];
    int ret = httpd_req_recv(req, content, sizeof(content));
    if (ret <= 0) {
        if (ret == HTTPD_SOCK_ERR_TIMEOUT) {
            httpd_resp_send_408(req);
        }
        return ESP_FAIL;
    }
    cJSON *root = cJSON_Parse(content);
    if (root == NULL) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    cJSON *ssid = cJSON_GetObjectItem(root, "SSID");
    cJSON *password = cJSON_GetObjectItem(root, "Password");
    if (!cJSON_IsString(ssid) || !cJSON_IsString(password)) {
        httpd_resp_send_500(req);
        cJSON_Delete(root);
        return ESP_FAIL;
    }
    wifi_config_t wifi_config = {
        .sta = {
            .ssid = "",
            .password = ""
        },
    };
    strncpy((char *)wifi_config.sta.ssid, ssid->valuestring, sizeof(wifi_config.sta.ssid));
    strncpy((char *)wifi_config.sta.password, password->valuestring, sizeof(wifi_config.sta.password));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_connect());
    cJSON_Delete(root);

    // Create a new socket in the new network
    int new_sock = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
    struct sockaddr_in new_addr;
    new_addr.sin_family = AF_INET;
    new_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    new_addr.sin_port = htons(0); // Let the system choose the port
    if (bind(new_sock, (struct sockaddr *)&new_addr, sizeof(new_addr)) != 0) {
        ESP_LOGE(TAG, "New socket unable to bind: errno %d", errno);
        close(new_sock);
        return ESP_FAIL;
    }
    socklen_t new_addr_len = sizeof(new_addr);
    if (getsockname(new_sock, (struct sockaddr *)&new_addr, &new_addr_len) != 0) {
        ESP_LOGE(TAG, "Unable to get socket name: errno %d", errno);
        close(new_sock);
        return ESP_FAIL;
    }
    char ip_str[16];
    inet_ntop(AF_INET, &new_addr.sin_addr, ip_str, sizeof(ip_str));
    int new_port = ntohs(new_addr.sin_port);
    cJSON *response = cJSON_CreateObject();
    cJSON_AddStringToObject(response, "IP", ip_str);
    cJSON_AddNumberToObject(response, "Port", new_port);
    const char *json_response = cJSON_Print(response);
    httpd_resp_send(req, json_response, strlen(json_response));
    cJSON_Delete(response);
    free((void *)json_response);
    return ESP_OK;
}

esp_err_t select_mode_handler(httpd_req_t *req) {
    ESP_LOGI(TAG, "Selecting Wi-Fi mode");
    char content[100];
    int ret = httpd_req_recv(req, content, sizeof(content));
    if (ret <= 0) {
        if (ret == HTTPD_SOCK_ERR_TIMEOUT) {
            httpd_resp_send_408(req);
        }
        return ESP_FAIL;
    }
    cJSON *root = cJSON_Parse(content);
    if (root == NULL) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    cJSON *mode = cJSON_GetObjectItem(root, "mode");
    if (!cJSON_IsString(mode)) {
        httpd_resp_send_500(req);
        cJSON_Delete(root);
        return ESP_FAIL;
    }
    if (strcmp(mode->valuestring, "External AP") == 0) {
        scan_wifi_handler(req);
    } else if (strcmp(mode->valuestring, "Internal AP") == 0) {
        // Create a new socket in the current network
        int new_sock = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
        struct sockaddr_in new_addr;
        new_addr.sin_family = AF_INET;
        new_addr.sin_addr.s_addr = htonl(INADDR_ANY);
        new_addr.sin_port = htons(0); // Let the system choose the port
        if (bind(new_sock, (struct sockaddr *)&new_addr, sizeof(new_addr)) != 0) {
            ESP_LOGE(TAG, "New socket unable to bind: errno %d", errno);
            close(new_sock);
            return ESP_FAIL;
        }
        socklen_t new_addr_len = sizeof(new_addr);
        if (getsockname(new_sock, (struct sockaddr *)&new_addr, &new_addr_len) != 0) {
            ESP_LOGE(TAG, "Unable to get socket name: errno %d", errno);
            close(new_sock);
            return ESP_FAIL;
        }
        char ip_str[16];
        inet_ntop(AF_INET, &new_addr.sin_addr, ip_str, sizeof(ip_str));
        int new_port = ntohs(new_addr.sin_port);
        cJSON *response = cJSON_CreateObject();
        cJSON_AddStringToObject(response, "IP", ip_str);
        cJSON_AddNumberToObject(response, "Port", new_port);
        const char *json_response = cJSON_Print(response);
        httpd_resp_send(req, json_response, strlen(json_response));
        cJSON_Delete(response);
        free((void *)json_response);
    }
    cJSON_Delete(root);
    return ESP_OK;
}

httpd_handle_t start_webserver(void) {
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.core_id = 0; // Run on core 0
    httpd_handle_t server = NULL;
    if (httpd_start(&server, &config) == ESP_OK) {
        httpd_uri_t scan_wifi_uri = {
            .uri = "/scan_wifi",
            .method = HTTP_GET,
            .handler = scan_wifi_handler,
            .user_ctx = NULL
        };
        httpd_register_uri_handler(server, &scan_wifi_uri);

        httpd_uri_t connect_wifi_uri = {
            .uri = "/connect_wifi",
            .method = HTTP_POST,
            .handler = connect_wifi_handler,
            .user_ctx = NULL
        };
        httpd_register_uri_handler(server, &connect_wifi_uri);

        httpd_uri_t select_mode_uri = {
            .uri = "/select_mode",
            .method = HTTP_POST,
            .handler = select_mode_handler,
            .user_ctx = NULL
        };
        httpd_register_uri_handler(server, &select_mode_uri);
    }

    return server;
}

void app_main(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    wifi_init(); // Inicializar Wi-Fi

    start_webserver(); // Iniciar servidor web
}