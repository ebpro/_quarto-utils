#!/bin/bash

echo "**☕ Java Development Environment**"
echo
echo "| Component | Details |"
echo "|-----------|----------|"

# Check Java version
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    JAVA_VENDOR=$(java -version 2>&1 | awk 'NR==1{print $1}')
    JAVA_HOME=${JAVA_HOME:-"Not set"}
    echo "| ☕ Java Runtime | \`$JAVA_VERSION\` ($JAVA_VENDOR) |"
fi

# Check Maven version
if command -v mvn >/dev/null 2>&1; then
    MVN_VERSION=$(mvn --version | awk 'NR==1{print $3}')
    MVN_HOME=$(mvn --version | grep "Maven home" | cut -d':' -f2 | xargs)
    echo "| 🎯 Maven | \`$MVN_VERSION\` |"
fi

# Check Gradle version
if command -v gradle >/dev/null 2>&1; then
    GRADLE_VERSION=$(gradle --version | awk '/Gradle / {print $2}')
    GRADLE_HOME=$(gradle --version | grep "Install" | cut -d':' -f2 | xargs)
    echo "| 🐘 Gradle | \`$GRADLE_VERSION\` |"
fi

echo