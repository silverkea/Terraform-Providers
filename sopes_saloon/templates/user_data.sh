#! /bin/bash
sudo amazon-linux-extras install -y nginx1
sudo service nginx start
sudo rm /usr/share/nginx/html/index.html
sudo cat > /usr/share/nginx/html/index.html << 'WEBSITE'
<html>
<head>
    <title>Sopes Saloon - ${environment}</title>
</head>
<body style="background-color:#8D4F1F">
    <p style="text-align: center;">
        <span style="color:#FFFFFF;">
            <span style="font-size:100px;">Welcome to the ${environment} Sopes Saloon!<br>Enjoy some &#127866; &#127838; &#127797;</span>
        </span>
    </p>
</body>
</html>
WEBSITE