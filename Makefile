.PHONY: tf-init tf-plan tf-apply tf-destroy ansible-db ansible-web ansible-all update-inventory

TF_DIR   := terraform
ANS_DIR  := ansible

## ── Terraform ────────────────────────────────────────────────────────────────

tf-init:
	cd $(TF_DIR) && terraform init

tf-plan:
	cd $(TF_DIR) && terraform plan

tf-apply:
	cd $(TF_DIR) && terraform apply -auto-approve

tf-destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

## ── Update Ansible inventory from Terraform outputs ──────────────────────────

update-inventory:
	@WEB_IP=$$(cd $(TF_DIR) && terraform output -raw web_server_public_ip); \
	DB_IP=$$(cd $(TF_DIR) && terraform output -raw db_server_private_ip); \
	sed -i "s/WEB_SERVER_PUBLIC_IP/$$WEB_IP/g" $(ANS_DIR)/inventory/hosts.ini; \
	sed -i "s/DB_SERVER_PRIVATE_IP/$$DB_IP/g" $(ANS_DIR)/inventory/hosts.ini; \
	echo "Inventory updated: web=$$WEB_IP  db=$$DB_IP"

## ── Ansible ──────────────────────────────────────────────────────────────────

ansible-ping:
	cd $(ANS_DIR) && ansible all -m ping

ansible-db:
	cd $(ANS_DIR) && ansible-playbook playbooks/database.yml

ansible-web:
	cd $(ANS_DIR) && ansible-playbook playbooks/webserver.yml

ansible-all:
	cd $(ANS_DIR) && ansible-playbook playbooks/site.yml

## ── Full deploy pipeline ─────────────────────────────────────────────────────

deploy: tf-apply update-inventory ansible-all
	@echo ""
	@echo "========================================="
	@echo " TravelMemory deployed!"
	@echo " URL: http://$$(cd $(TF_DIR) && terraform output -raw web_server_public_ip)"
	@echo "========================================="
