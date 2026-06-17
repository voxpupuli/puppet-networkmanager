# networkmanager

⚠️ This is heavly work in progress and not ready for production use. ⚠️

This module manages NetworkManager on Linux systems.

## Testing

```shell
vagrant up
vagrant ssh
sudo -i
puppet apply -e 'include "networkmanager"' --noop
```
