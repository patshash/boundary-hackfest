DATETIME=$(date +'%d%m%Y_%H%M%S')
cp ./generated/auth_request_token ./generated/auth_request_token_$DATETIME 
echo '' > ./generated/auth_request_token 
cp ./generated/k8s_auth_request_token ./generated/k8s_auth_request_token_$DATETIME 
echo '' > ./generated/k8s_auth_request_token
cp ./generated/boundary_cluster_id ./generated/boundary_cluster_id_$DATETIME 
echo '' > ./generated/boundary_cluster_id 
cp ./generated/global_auth_method_id ./generated/global_auth_method_id_$DATETIME 
echo '' > ./generated/global_auth_method_id 
cp ./generated/vault-token  ./generated/vault-token_$DATETIME 
echo '' > ./generated/vault-token 
cp ./generated/ssh-key ./generated/ssh-key_$DATETIME 
echo '' > ./generated/ssh-key

