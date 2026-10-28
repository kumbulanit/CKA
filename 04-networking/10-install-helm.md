#### Documentation Referred:

https://helm.sh/docs/intro/install/

#### 2.Installing Helm in Ubuntu:

Helm's apt repository has moved; the old `baltocdn.com` repository no longer serves packages.

```sh
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

##### Step 2: Verify if Helm Command is working

```sh
helm version
```
