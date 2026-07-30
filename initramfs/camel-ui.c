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
#include <drm_fourcc.h>

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

static uint32_t property_id(int fd, uint32_t object, uint32_t type,
                            const char *name) {
  drmModeObjectProperties *ps=drmModeObjectGetProperties(fd,object,type);
  uint32_t found=0;
  if (!ps) return 0;
  for (uint32_t i=0;i<ps->count_props;i++) {
    drmModePropertyRes *p=drmModeGetProperty(fd,ps->props[i]);
    if (p && !strcmp(p->name,name)) found=p->prop_id;
    drmModeFreeProperty(p);
    if (found) break;
  }
  drmModeFreeObjectProperties(ps);
  return found;
}

static uint64_t property_value(int fd, uint32_t object, uint32_t type,
                               const char *name) {
  drmModeObjectProperties *ps=drmModeObjectGetProperties(fd,object,type);
  uint64_t found=0;
  if (!ps) return 0;
  for (uint32_t i=0;i<ps->count_props;i++) {
    drmModePropertyRes *p=drmModeGetProperty(fd,ps->props[i]);
    if (p && !strcmp(p->name,name)) found=ps->prop_values[i];
    drmModeFreeProperty(p);
    if (found) break;
  }
  drmModeFreeObjectProperties(ps);
  return found;
}

static int add(drmModeAtomicReq *req, uint32_t object, uint32_t property,
               uint64_t value) {
  return property && drmModeAtomicAddProperty(req,object,property,value)>=0;
}

static int atomic_display(int fd, drmModeRes *r, drmModeConnector *c,
                          uint32_t crtc, uint32_t fb,
                          drmModeModeInfo *mode) {
  int crtc_index=-1;
  for (int i=0;i<r->count_crtcs;i++) if (r->crtcs[i]==crtc) crtc_index=i;
  if (crtc_index<0) return -1;
  if (drmSetClientCap(fd,DRM_CLIENT_CAP_UNIVERSAL_PLANES,1)) return -2;
  if (drmSetClientCap(fd,DRM_CLIENT_CAP_ATOMIC,1)) return -3;

  uint32_t plane=0;
  drmModePlaneRes *prs=drmModeGetPlaneResources(fd);
  for (uint32_t i=0;prs && i<prs->count_planes;i++) {
    drmModePlane *p=drmModeGetPlane(fd,prs->planes[i]);
    if (p && (p->possible_crtcs&(1u<<crtc_index)) &&
        property_value(fd,p->plane_id,DRM_MODE_OBJECT_PLANE,"type")==
          DRM_PLANE_TYPE_PRIMARY) {
      plane=p->plane_id;
      if (property_value(fd,p->plane_id,DRM_MODE_OBJECT_PLANE,
                         "CRTC_ID")==crtc) {
        drmModeFreePlane(p);
        break;
      }
    }
    drmModeFreePlane(p);
  }
  drmModeFreePlaneResources(prs);
  if (!plane) return -4;

  uint32_t blob=0;
  if (drmModeCreatePropertyBlob(fd,mode,sizeof(*mode),&blob)) return -5;
  drmModeAtomicReq *req=drmModeAtomicAlloc();
  int ok=req &&
    add(req,c->connector_id,property_id(fd,c->connector_id,
        DRM_MODE_OBJECT_CONNECTOR,"CRTC_ID"),crtc) &&
    add(req,crtc,property_id(fd,crtc,DRM_MODE_OBJECT_CRTC,"MODE_ID"),blob) &&
    add(req,crtc,property_id(fd,crtc,DRM_MODE_OBJECT_CRTC,"ACTIVE"),1) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"FB_ID"),fb) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"CRTC_ID"),crtc) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"SRC_X"),0) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"SRC_Y"),0) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"SRC_W"),
        (uint64_t)mode->hdisplay<<16) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"SRC_H"),
        (uint64_t)mode->vdisplay<<16) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"CRTC_X"),0) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"CRTC_Y"),0) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"CRTC_W"),
        mode->hdisplay) &&
    add(req,plane,property_id(fd,plane,DRM_MODE_OBJECT_PLANE,"CRTC_H"),
        mode->vdisplay);
  int rc=ok?drmModeAtomicCommit(fd,req,DRM_MODE_ATOMIC_ALLOW_MODESET,NULL):-6;
  drmModeAtomicFree(req);
  drmModeDestroyPropertyBlob(fd,blob);
  return rc;
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
    if (c && c->connector_type==DRM_MODE_CONNECTOR_DSI &&
        c->connection==DRM_MODE_CONNECTED && c->count_modes) break;
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
  uint32_t handles[4]={d.handle}, pitches[4]={d.pitch}, offsets[4]={0};
  if (drmModeAddFB2(fd,d.width,d.height,DRM_FORMAT_XRGB8888,
                    handles,pitches,offsets,&fb,0)) {
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
  if (atomic_display(fd,r,c,crtc,fb,&mode)) {
    kmsg("UI_FAIL=ATOMIC_COMMIT"); return 16;
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
