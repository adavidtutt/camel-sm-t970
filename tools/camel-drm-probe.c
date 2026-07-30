#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

static void properties(int fd, uint32_t id, uint32_t type, const char *kind) {
  drmModeObjectProperties *ps = drmModeObjectGetProperties(fd, id, type);
  if (!ps) return;
  for (uint32_t i = 0; i < ps->count_props; i++) {
    drmModePropertyRes *p = drmModeGetProperty(fd, ps->props[i]);
    if (p) {
      printf("%s id=%u property=%s property_id=%u value=%" PRIu64 "\n",
             kind, id, p->name, p->prop_id, ps->prop_values[i]);
      drmModeFreeProperty(p);
    }
  }
  drmModeFreeObjectProperties(ps);
}

int main(void) {
  int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
  if (fd < 0) { perror("open card0"); return 1; }
  uint64_t value = 0;
  if (!drmGetCap(fd, DRM_CAP_DUMB_BUFFER, &value))
    printf("cap_dumb_buffer=%" PRIu64 "\n", value);
  printf("set_universal_planes=%d\n",
         drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1));
  printf("set_atomic=%d\n", drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1));

  drmModeRes *r = drmModeGetResources(fd);
  if (!r) { perror("get resources"); return 2; }
  printf("resources connectors=%d crtcs=%d encoders=%d\n",
         r->count_connectors, r->count_crtcs, r->count_encoders);
  for (int i = 0; i < r->count_connectors; i++) {
    drmModeConnector *c = drmModeGetConnector(fd, r->connectors[i]);
    if (!c) continue;
    printf("connector id=%u type=%u connection=%u encoder=%u modes=%d\n",
           c->connector_id, c->connector_type, c->connection,
           c->encoder_id, c->count_modes);
    for (int m = 0; m < c->count_modes && m < 4; m++)
      printf(" mode %s %ux%u clock=%u flags=0x%x type=0x%x\n",
             c->modes[m].name, c->modes[m].hdisplay, c->modes[m].vdisplay,
             c->modes[m].clock, c->modes[m].flags, c->modes[m].type);
    properties(fd, c->connector_id, DRM_MODE_OBJECT_CONNECTOR, "connector");
    drmModeFreeConnector(c);
  }
  for (int i = 0; i < r->count_crtcs; i++) {
    printf("crtc index=%d id=%u\n", i, r->crtcs[i]);
    properties(fd, r->crtcs[i], DRM_MODE_OBJECT_CRTC, "crtc");
  }
  drmModePlaneRes *planes = drmModeGetPlaneResources(fd);
  if (planes) {
    printf("planes=%u\n", planes->count_planes);
    for (uint32_t i = 0; i < planes->count_planes; i++) {
      drmModePlane *p = drmModeGetPlane(fd, planes->planes[i]);
      if (!p) continue;
      printf("plane id=%u possible_crtcs=0x%x formats=%u\n",
             p->plane_id, p->possible_crtcs, p->count_formats);
      properties(fd, p->plane_id, DRM_MODE_OBJECT_PLANE, "plane");
      drmModeFreePlane(p);
    }
    drmModeFreePlaneResources(planes);
  }
  drmModeFreeResources(r);
  close(fd);
  return 0;
}
