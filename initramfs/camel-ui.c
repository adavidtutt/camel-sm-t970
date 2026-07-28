#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/reboot.h>
#include <sys/select.h>
#include <time.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

static const uint8_t font[][5] = {
  {0x7e,0x11,0x11,0x11,0x7e},{0x7f,0x49,0x49,0x49,0x36},
  {0x3e,0x41,0x41,0x41,0x22},{0x7f,0x41,0x41,0x22,0x1c},
  {0x7f,0x49,0x49,0x49,0x41},{0x7f,0x09,0x09,0x09,0x01},
  {0x3e,0x41,0x49,0x49,0x7a},{0x7f,0x08,0x08,0x08,0x7f},
  {0x00,0x41,0x7f,0x41,0x00},{0x20,0x40,0x41,0x3f,0x01},
  {0x7f,0x08,0x14,0x22,0x41},{0x7f,0x40,0x40,0x40,0x40},
  {0x7f,0x02,0x0c,0x02,0x7f},{0x7f,0x04,0x08,0x10,0x7f},
  {0x3e,0x41,0x41,0x41,0x3e},{0x7f,0x09,0x09,0x09,0x06},
  {0x3e,0x41,0x51,0x21,0x5e},{0x7f,0x09,0x19,0x29,0x46},
  {0x46,0x49,0x49,0x49,0x31},{0x01,0x01,0x7f,0x01,0x01},
  {0x3f,0x40,0x40,0x40,0x3f},{0x1f,0x20,0x40,0x20,0x1f},
  {0x3f,0x40,0x38,0x40,0x3f},{0x63,0x14,0x08,0x14,0x63},
  {0x07,0x08,0x70,0x08,0x07},{0x61,0x51,0x49,0x45,0x43},
  {0x3e,0x51,0x49,0x45,0x3e},{0x00,0x42,0x7f,0x40,0x00},
  {0x42,0x61,0x51,0x49,0x46},{0x21,0x41,0x45,0x4b,0x31},
  {0x18,0x14,0x12,0x7f,0x10},{0x27,0x45,0x45,0x45,0x39},
  {0x3c,0x4a,0x49,0x49,0x30},{0x01,0x71,0x09,0x05,0x03},
  {0x36,0x49,0x49,0x49,0x36},{0x06,0x49,0x49,0x29,0x1e}
};

static const uint8_t *glyph(char c) {
  static const uint8_t blank[5];
  if (c >= 'A' && c <= 'Z') return font[c-'A'];
  if (c >= '0' && c <= '9') return font[26+c-'0'];
  return blank;
}

static void text(uint32_t *p, int stride, int width, int height,
                 int x, int y, int scale, const char *s, uint32_t color) {
  for (; *s; s++, x += 6*scale) {
    const uint8_t *g = glyph(*s);
    for (int col=0; col<5; col++) for (int row=0; row<7; row++)
      if (g[col] & (1u << row))
        for (int yy=0; yy<scale; yy++) for (int xx=0; xx<scale; xx++) {
          int px=x+col*scale+xx, py=y+row*scale+yy;
          if (px>=0 && py>=0 && px<width && py<height)
            p[py*stride+px]=color;
        }
  }
}

static void kmsg(const char *s) {
  int fd=open("/dev/kmsg",O_WRONLY);
  if (fd>=0) { dprintf(fd,"<6>CAMEL: %s\n",s); close(fd); }
}

int main(void) {
  int fd=-1;
  for (int n=0;n<100 && fd<0;n++) {
    fd=open("/dev/dri/card0",O_RDWR|O_CLOEXEC);
    if (fd<0) usleep(100000);
  }
  if (fd<0) { kmsg("UI_FAIL=NO_DRM"); return 10; }
  drmModeRes *r=drmModeGetResources(fd);
  drmModeConnector *c=NULL;
  for (int i=0;r && i<r->count_connectors;i++) {
    c=drmModeGetConnector(fd,r->connectors[i]);
    if (c && c->connection==DRM_MODE_CONNECTED && c->count_modes) break;
    drmModeFreeConnector(c); c=NULL;
  }
  if (!r || !c) { kmsg("UI_FAIL=NO_CONNECTOR"); return 11; }
  drmModeModeInfo mode=c->modes[0];
  drmModeEncoder *e=c->encoder_id?drmModeGetEncoder(fd,c->encoder_id):NULL;
  uint32_t crtc=e?e->crtc_id:(r->count_crtcs?r->crtcs[0]:0);
  struct drm_mode_create_dumb d={.width=mode.hdisplay,.height=mode.vdisplay,
    .bpp=32};
  if (ioctl(fd,DRM_IOCTL_MODE_CREATE_DUMB,&d)<0) {
    kmsg("UI_FAIL=CREATE_DUMB"); return 12;
  }
  uint32_t fb=0;
  if (drmModeAddFB(fd,d.width,d.height,24,32,d.pitch,d.handle,&fb)) {
    kmsg("UI_FAIL=ADD_FB"); return 13;
  }
  struct drm_mode_map_dumb m={.handle=d.handle};
  if (ioctl(fd,DRM_IOCTL_MODE_MAP_DUMB,&m)<0) return 14;
  uint32_t *p=mmap(NULL,d.size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,m.offset);
  if (p==MAP_FAILED) return 15;
  memset(p,0,d.size);
  int scale=d.width/240; if(scale<2) scale=2; if(scale>7) scale=7;
  uint32_t green=0x0000ff66;
  text(p,d.pitch/4,d.width,d.height,d.width/12,d.height/7,scale,
       "CAMEL LINUX",green);
  text(p,d.pitch/4,d.width,d.height,d.width/12,d.height/7+12*scale,scale/2+1,
       "RAM RECOVERY READY",green);
  text(p,d.pitch/4,d.width,d.height,d.width/12,d.height/2,scale/2+1,
       "VOLUME UP   STAY IN CAMEL",green);
  text(p,d.pitch/4,d.width,d.height,d.width/12,d.height/2+10*scale,scale/2+1,
       "VOLUME DOWN BOOT ANDROID",green);
  text(p,d.pitch/4,d.width,d.height,d.width/12,d.height-18*scale,scale/2+1,
       "AUTO BOOT ANDROID IN 60 SECONDS",green);
  if (drmModeSetCrtc(fd,crtc,fb,0,0,&c->connector_id,1,&mode)) {
    kmsg("UI_FAIL=SET_CRTC"); return 16;
  }
  kmsg("UI_READY=1");

  int inputs[32], count=0;
  for (int n=0;n<32;n++) {
    char path[64]; snprintf(path,sizeof(path),"/dev/input/event%d",n);
    int x=open(path,O_RDONLY|O_NONBLOCK);
    if(x>=0) inputs[count++]=x;
  }
  time_t deadline=time(NULL)+60;
  for (;;) {
    fd_set set; FD_ZERO(&set); int max=-1;
    for(int i=0;i<count;i++){FD_SET(inputs[i],&set);if(inputs[i]>max)max=inputs[i];}
    struct timeval tv={.tv_sec=1};
    int ready=select(max+1,&set,NULL,NULL,&tv);
    if(ready>0) for(int i=0;i<count;i++) if(FD_ISSET(inputs[i],&set)) {
      struct input_event ev;
      while(read(inputs[i],&ev,sizeof(ev))==sizeof(ev))
        if(ev.type==EV_KEY && ev.value==1) {
          if(ev.code==KEY_VOLUMEUP) {
            deadline=0; kmsg("UI_ACTION=STAY");
            text(p,d.pitch/4,d.width,d.height,d.width/12,d.height-8*scale,
                 scale/2+1,"AUTO BOOT CANCELLED",green);
          } else if(ev.code==KEY_VOLUMEDOWN) {
            kmsg("UI_ACTION=ANDROID"); sync(); reboot(RB_AUTOBOOT);
          }
        }
    }
    if(deadline && time(NULL)>=deadline) {
      kmsg("UI_ACTION=AUTO_ANDROID"); sync(); reboot(RB_AUTOBOOT);
    }
  }
}
