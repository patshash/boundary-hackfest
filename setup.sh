DATETIME=$(date +'%d%m%Y_%H%M%S')

if [ ! -d "./generated" ]; then
  mkdir ./generated
fi

cp ./generated/worker_ingress_auth_request_token ./generated/worker_ingress_auth_request_token_$DATETIME 
echo '' > ./generated/worker_ingress_auth_request_token 
cp ./generated/worker_egress_auth_request_token ./generated/worker_egress_auth_request_token_$DATETIME 
echo '' > ./generated/worker_egress_auth_request_token
cp ./generated/k8s_auth_request_token ./generated/k8s_auth_request_token_$DATETIME 
echo '' > ./generated/k8s_auth_request_token
cp ./generated/boundary_cluster_id ./generated/boundary_cluster_id_$DATETIME 
echo '' > ./generated/boundary_cluster_id 
cp ./generated/global_auth_method_id ./generated/global_auth_method_id_$DATETIME 
echo '' > ./generated/global_auth_method_id 
cp ./generated/vault_token  ./generated/vault_token_$DATETIME 
echo '' > ./generated/vault_token 
cp ./generated/ssh_key ./generated/ssh_key_$DATETIME 
echo '' > ./generated/ssh_key
cp ./generated/rsa_key ./generated/rsa__$DATETIME 
echo '' > ./generated/rsa_key
cp ./generated/boundary_token ./generated/boundary_token_$DATETIME 
echo '' > ./generated/boundary_token
cp ./generated/vault_credstore_id ./generated/vault_credstore_id_$DATETIME 
echo '' > ./generated/vault_credstore_id

