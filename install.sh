
# depends for ocr, reading pdfs, office docs, etc
apt-get install libreoffice -y
apt-get install xpdf-utils -y

sudo apt-get install imagemagick -y

sudo apt-get install tesseract-ocr -y

sudo apt-get install pdftk -y

#grab node
git clone git://github.com/joyent/node.git
cd node
git checkout v0.6.8
./configure
make
sudo make install

cd ../

#npm
git clone git://github.com/isaacs/npm.git
cd npm/scripts
chmod +x install.sh
sudo ./install.sh

cd ../


# Amazon s3 fuse support to mount s4 bundle as drive
# http://code.google.com/p/s3fs/wiki/FuseOverAmazon
sudo apt-get install -y subversion build-essential libfuse-dev fuse-utils libcurl4-openssl-dev libxml2-dev mime-support
svn checkout http://s3fs.googlecode.com/svn/trunk/ s3fs
cd s3fs/
autoreconf --install
./configure --prefix=/usr
make
sudo make install
# Add AWS security creds to /etc/passwd-s3fs as accessKeyId:secretAccessKey
#sudo chmod 640 /etc/passwd-s3fs
# Then run and access at /mnt
#/usr/bin/s3fs mybucket /mnt
# Add to crontab as @reboot /usr/bin/s3fs lexile /mnt

