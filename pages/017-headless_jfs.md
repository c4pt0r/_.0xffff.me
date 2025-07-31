
1. Go to [tidbcloud console](https://tidbcloud.com) and create a new TiDB serverless cluster (free).
2. Create a new database named jfs

```
CREATE DATABASE jfs;
```

3. .env exmple

```
TIDB_HOST=gatewayXXX.YYY.prod.aws.tidbcloud.com
TIDB_PORT=4000
TIDB_USERNAME=<username>
TIDB_PASSWORD=<password>
TIDB_DATABASE=jfs
```

4. jfs.sh

```
#!/bin/bash

# Load environment variables from .env file
source .env

# Function to show usage
show_usage() {
    echo "Usage: $0 <command> [mount_point]"
    echo "Commands:"
    echo "  mount [mount_point]   - Mount JuiceFS (default: ./jfs)"
    echo "  umount [mount_point]  - Unmount JuiceFS (default: ./jfs)"
    exit 1
}

# Function to mount JuiceFS
mount_jfs() {
    local mount_point=${1:-"./jfs"}
    echo "Mounting JuiceFS to: $mount_point"
    juicefs mount -d "mysql://${TIDB_USERNAME}:${TIDB_PASSWORD}@tcp(${TIDB_HOST}:${TIDB_PORT})/${TIDB_DATABASE}?tls=true" "$mount_point"
}

# Function to unmount JuiceFS
umount_jfs() {
    local mount_point=${1:-"./jfs"}
    echo "Unmounting JuiceFS from: $mount_point"
    juicefs umount "$mount_point"
}

# Check if command is provided
if [ $# -eq 0 ]; then
    show_usage
fi

# Parse command
case "$1" in
    mount)
        mount_jfs "$2"
        ;;
    umount)
        umount_jfs "$2"
        ;;
    *)
        echo "Error: Unknown command '$1'"
        show_usage
        ;;
esac
```

6. Run the script to mount JuiceFS

```
chmod +x jfs.sh
./jfs.sh mount <mount_point>
```

