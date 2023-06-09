

#ifndef __BTF_PARSE_H
#define __BTF_PARSE_H



/**
 * btf_load: load btf from btf_custom_path
 * 
 * @btf_custom_path: path of btf file
 */
void *btf_load(const char *btf_custom_path);
typedef unsigned int uint32_t;

struct member_attribute
{
    uint32_t size;      // size of structure's member
    uint32_t real_size; // real_size mean 
    uint32_t offset;    // offset of member in strucutre
};

/**
 * btf_find_struct_member - find struct btfid by structure's name
 * 
 * @btf: 
 * @struct_name: name of struct
 * @member_name: name of structure's member
 * @return: NULL mean error, get error number from errno. 
 * 
 * Note: Remember to free pointer of struct member_attribute
 */
struct member_attribute *btf_find_struct_member(void *btf, const char *struct_name, const char *member_name);


#endif

