#! /bin/bash

export KEY_NAME="ik42p.kubasobon.com"
export KEY_COMMENT="Testing SOPS for ista"

echo "Generating GPG key..."
gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Comment: ${KEY_COMMENT}
Name-Real: ${KEY_NAME}
EOF

export KEY_FP=$(gpg --list-secret-keys "${KEY_NAME}" | head -n2 | tail -n 1 | awk '{print $1}')
echo "Generated key $KEY_NAME ($KEY_FP)"

 echo "Creating k8s secret..."
 gpg --export-secret-keys --armor "${KEY_FP}" |
 kubectl create secret generic sops-gpg \
 --namespace=flux-app \
 --from-file=sops.asc=/dev/stdin

echo "Exporting keys..."
gpg --export-secret-keys --armor "${KEY_FP}" > private.key
gpg --export --armor "${KEY_FP}" > public.key
gpg --export --armor "${KEY_FP}" > ./encrypted-data/.sops.pub.asc

echo "Creating encrypted-data/.sops.yaml rules..."
cat <<EOF > ./encrypted-data/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: "${KEY_FP}"
EOF
cat <<EOF > ./encrypted-data-before-sops/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: "${KEY_FP}"
EOF

echo "Encrypting sample.yaml..."
cd ./encrypted-data-before-sops
sops --encrypt \
     --pgp "${KEY_FP}" \
     sample.yaml \
     > ../encrypted-data/sample.yaml

echo "Done!"

# If you want to delete the keys from your keychain
# gpg --delete-secret-keys "${KEY_FP}"
