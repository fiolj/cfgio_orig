! Program :
! Author  : wansooha@gmail.com
! Date    :

module cfgio_mod
    use string_conv_mod, only: from_string,tolist,unquote,list_size,list_size_cmplx,list_size_str
    implicit none
    private
    public:: cfg_t, parse_cfg !! main
    public:: dict_t,cfg_sect_t

    integer,parameter:: MXNSTR=256
    integer,parameter:: STDIN=5,STDOUT=6,STDERR=0
    integer,parameter:: sp=kind(0.0)
    integer,parameter:: dp=kind(0.d0)
    character(len=8),parameter:: defaults="DEFAULTS"

    type dict_t
        character(len=:),allocatable:: key,val
    end type

    type cfg_sect_t
        character(len=:),allocatable:: section
        type(dict_t),dimension(:),allocatable :: p
        contains
            procedure:: has_key => sect_has_key
            procedure:: npar => sect_npar
    end type

    type cfg_t
        type(cfg_sect_t),dimension(:),allocatable :: s
        contains
            procedure:: nsect => cfg_nsect

            generic,public:: print => print_cfg,write_cfg_file
            generic,public:: write => print_cfg,write_cfg_file
            procedure,private:: print_cfg
            procedure,private:: write_cfg_file

            procedure,public:: has_section
            procedure,public:: has_key

            generic,public:: gets => cfg_gets,cfg_gets_opt
            generic,public:: getb => cfg_getb,cfg_getb_opt
            generic,public:: geti => cfg_geti,cfg_geti_opt
            generic,public:: getf => cfg_getf,cfg_getf_opt
            generic,public:: getd => cfg_getd,cfg_getd_opt
            generic,public:: getc => cfg_getc,cfg_getc_opt
            generic,public:: getz => cfg_getz,cfg_getz_opt
            procedure,private:: cfg_gets
            procedure,private:: cfg_getb
            procedure,private:: cfg_geti
            procedure,private:: cfg_getf
            procedure,private:: cfg_getd
            procedure,private:: cfg_getc
            procedure,private:: cfg_getz

            procedure,private:: cfg_gets_opt
            procedure,private:: cfg_getb_opt
            procedure,private:: cfg_geti_opt
            procedure,private:: cfg_getf_opt
            procedure,private:: cfg_getd_opt
            procedure,private:: cfg_getc_opt
            procedure,private:: cfg_getz_opt

            generic,public:: get => get_sarr,get_barr,get_iarr,get_farr,get_darr,get_carr,get_zarr, &
                cfg_get_s,cfg_get_b,cfg_get_i,cfg_get_f,cfg_get_d,cfg_get_c,cfg_get_z, &
                cfg_get_s_opt,cfg_get_b_opt,cfg_get_i_opt,cfg_get_f_opt,cfg_get_d_opt,cfg_get_c_opt,cfg_get_z_opt
            generic,public:: set => set_sarr,set_barr,set_iarr,set_farr,set_darr,set_carr,set_zarr, &
                cfg_sets,cfg_setb,cfg_seti,cfg_setf,cfg_setd,cfg_setc,cfg_setz

            procedure,private:: get_sarr
            procedure,private:: get_barr
            procedure,private:: get_iarr
            procedure,private:: get_farr
            procedure,private:: get_darr
            procedure,private:: get_carr
            procedure,private:: get_zarr

            procedure,private:: cfg_get_s
            procedure,private:: cfg_get_b
            procedure,private:: cfg_get_i
            procedure,private:: cfg_get_f
            procedure,private:: cfg_get_d
            procedure,private:: cfg_get_c
            procedure,private:: cfg_get_z

            procedure,private:: cfg_get_s_opt
            procedure,private:: cfg_get_b_opt
            procedure,private:: cfg_get_i_opt
            procedure,private:: cfg_get_f_opt
            procedure,private:: cfg_get_d_opt
            procedure,private:: cfg_get_c_opt
            procedure,private:: cfg_get_z_opt

            procedure,private:: cfg_sets
            procedure,private:: cfg_setb
            procedure,private:: cfg_seti
            procedure,private:: cfg_setf
            procedure,private:: cfg_setd
            procedure,private:: cfg_setc
            procedure,private:: cfg_setz

            procedure,private:: set_sarr
            procedure,private:: set_barr
            procedure,private:: set_iarr
            procedure,private:: set_farr
            procedure,private:: set_darr
            procedure,private:: set_carr
            procedure,private:: set_zarr
    end type

contains

! find sect / par length
    integer function sect_npar(cfgs) result(npar)
    class(cfg_sect_t),intent(in):: cfgs
    if(allocated(cfgs%p))then
        npar = size(cfgs%p)
    else
        npar = 0
    end if
    end function
    integer function cfg_nsect(cfg) result(nsect)
    class(cfg_t),intent(in):: cfg
    if(allocated(cfg%s))then
        nsect = size(cfg%s)
    else
        nsect = 0
    end if
    end function

! find section, key
    integer function find_isect(cfg,section,found) result(isect)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section
    logical,intent(out):: found
    found=.false.
    do isect=1,cfg%nsect()
        if(trim(adjustl(cfg%s(isect)%section)).eq.section) then
            found=.true.
            return
        endif
    enddo
    ! if not found section should not use isect
    isect = -1
    end function

    logical function has_section(cfg,section) result(found)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section
    integer isect
    found=.false.
    do isect=1,cfg%nsect()
        if(trim(adjustl(cfg%s(isect)%section)).eq.section) then
            found=.true.
            return
        endif
    enddo
    end function

    integer function find_ikey(cfgs,key,found) result(ikey)
    class(cfg_sect_t),intent(in):: cfgs
    character(len=*),intent(in):: key
    logical,intent(out):: found
    found=.false.
    do ikey=1,cfgs%npar()
        if(cfgs%p(ikey)%key.eq.key) then
            found=.true.
            return
        endif
    enddo
    ! if not found par should not use ikey
    ikey = -1
    end function

    logical function sect_has_key(cfgs,key) result(found)
    class(cfg_sect_t),intent(in):: cfgs
    character(len=*),intent(in):: key
    integer ikey
    found=.false.
    do ikey=1,cfgs%npar()
        if(trim(adjustl(cfgs%p(ikey)%key)).eq.key) then
            found=.true.
            return
        endif
    enddo
    end function

    logical function has_key(cfg,section,key,search_defaults) result(found)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    logical,intent(in),optional:: search_defaults
    logical:: try_defaults=.true.
    integer isect
    if(present(search_defaults)) try_defaults=search_defaults
    isect=find_isect(cfg,section,found)
    if(found) then
        found=sect_has_key(cfg%s(isect),key)
        if(found) return
    endif
    if(try_defaults) then ! try DEFAULTS section
        isect=find_isect(cfg,defaults,found)
        if(found) found=sect_has_key(cfg%s(isect),key)
    endif
    end function

    subroutine find_sect_key(cfg,section,key,isect,ikey)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    integer,intent(out):: isect,ikey
    logical:: found
    isect=find_isect(cfg,section,found)
    if(.not.found) call errexit("Cannot find the section: "//section)
    ikey=find_ikey(cfg%s(isect),key,found)
    if(.not.found) call errexit("Cannot find the key: "//key)
    end subroutine

! setter
    subroutine cfg_sets(cfg,section,key,val)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    character(len=*),intent(in):: val
    integer isect,ikey
    logical found
    type(cfg_sect_t):: new_s
    isect=find_isect(cfg,section,found)
    if(.not.found) then
        new_s%section=trim(adjustl(section))
        allocate(new_s%p(0))
        if(.not.allocated(cfg%s)) allocate(cfg%s(0))
        cfg%s = [cfg%s, new_s]
        isect=cfg%nsect()
    endif
    ikey=find_ikey(cfg%s(isect),key,found)
    if(.not.found) then
        if(.not. allocated(cfg%s(isect)%p)) allocate(cfg%s(isect)%p(0))
        cfg%s(isect)%p = [cfg%s(isect)%p, dict_t(key, val)]
    else
        cfg%s(isect)%p(ikey)%val=val
    endif
    end subroutine
    subroutine cfg_seti(cfg,section,key,val)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    integer,intent(in):: val
    character(len=MXNSTR):: str
    write(str,*) val
    call cfg_sets(cfg,section,key,trim(adjustl(str)))
    end subroutine
    subroutine cfg_setf(cfg,section,key,val)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    real(sp),intent(in):: val
    character(len=MXNSTR):: str
    write(str,*) val
    call cfg_sets(cfg,section,key,trim(adjustl(str)))
    end subroutine
    subroutine cfg_setd(cfg,section,key,val)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    real(dp),intent(in):: val
    character(len=MXNSTR):: str
    write(str,*) val
    call cfg_sets(cfg,section,key,trim(adjustl(str)))
    end subroutine
    subroutine cfg_setc(cfg,section,key,val)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    complex(sp),intent(in):: val
    character(len=MXNSTR):: str
    write(str,*) val
    call cfg_sets(cfg,section,key,trim(adjustl(str)))
    end subroutine
    subroutine cfg_setz(cfg,section,key,val)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    complex(dp),intent(in):: val
    character(len=MXNSTR):: str
    write(str,*) val
    call cfg_sets(cfg,section,key,trim(adjustl(str)))
    end subroutine
    subroutine cfg_setb(cfg,section,key,val)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    logical,intent(in):: val
    character(len=MXNSTR):: str
    write(str,*) val
    call cfg_sets(cfg,section,key,trim(adjustl(str)))
    end subroutine

! set list
    subroutine set_iarr(cfg,section,key,arr)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    integer,intent(in):: arr(:)
    call cfg_sets(cfg,section,key,trim(adjustl(tolist(arr))))
    end subroutine
    subroutine set_farr(cfg,section,key,arr)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    real(sp),intent(in):: arr(:)
    call cfg_sets(cfg,section,key,trim(adjustl(tolist(arr))))
    end subroutine
    subroutine set_darr(cfg,section,key,arr)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    real(dp),intent(in):: arr(:)
    call cfg_sets(cfg,section,key,trim(adjustl(tolist(arr))))
    end subroutine
    subroutine set_barr(cfg,section,key,arr)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    logical,intent(in):: arr(:)
    call cfg_sets(cfg,section,key,trim(adjustl(tolist(arr))))
    end subroutine
    subroutine set_carr(cfg,section,key,arr)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    complex(sp),intent(in):: arr(:)
    call cfg_sets(cfg,section,key,trim(adjustl(tolist(arr))))
    end subroutine
    subroutine set_zarr(cfg,section,key,arr)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    complex(dp),intent(in):: arr(:)
    call cfg_sets(cfg,section,key,trim(adjustl(tolist(arr))))
    end subroutine
    subroutine set_sarr(cfg,section,key,arr)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: section,key
    character(len=*),intent(in):: arr(:)
    call cfg_sets(cfg,section,key,trim(adjustl(tolist(arr))))
    end subroutine

! getter functions
    function cfg_gets_basic(cfg,section,key) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    character(len=:),allocatable:: val
    integer isect,ikey
    logical found
    isect=find_isect(cfg,section,found)
    if(.not.found) then ! try DEFAULTS section
        isect=find_isect(cfg,defaults,found)
        if(.not.found) call errexit("Cannot find the section:"//section)
    endif
    ikey=find_ikey(cfg%s(isect),key,found)
    if(found) then
        val=cfg%s(isect)%p(ikey)%val
    else ! try DEFAULTS section
        isect=find_isect(cfg,defaults,found)
        if(.not.found) call errexit("Cannot find the key:"//key)
        ikey=find_ikey(cfg%s(isect),key,found)
        if(.not.found) call errexit("Cannot find the key:"//key)
        val=cfg%s(isect)%p(ikey)%val
    endif
    val=unquote(val)
    end function

    function interpolate_str(cfg,section,str) result(val)
    ! interpolation ${section:key}
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,str
    character(len=:),allocatable:: val
    character(len=MXNSTR):: intpl,key,intpl_section,intplstr
    character:: sep=':'
    integer i,istart,iend,isep
    logical found
    intpl=trim(adjustl(str))
    do while(.true.)
        found=.false.
        do i=1,len_trim(intpl)
            if(intpl(i:i+1)=="${") then
                istart=i
                iend=index(intpl(istart+2:),'}')
                if(iend==0) exit ! intpl close '}' not found

                found=.true.
                iend=istart+1+iend
                key=intpl(istart+2:iend-1)

                ! is section given?
                isep=index(trim(key),sep)
                if(isep>0) then ! ${section:key}
                    intpl_section=key(1:isep-1)
                    key=trim(key(isep+1:))
                    intplstr=trim(cfg_gets_basic(cfg,intpl_section,key))
                else ! ${key} - check current section(and defaults section)
                    intplstr=trim(cfg_gets_basic(cfg,section,key))
                endif
                intpl=intpl(1:istart-1)//trim(intplstr)//trim(intpl(iend+1:))
            endif
        enddo
        if(.not.found) exit
    enddo
    val=trim(intpl)
    end function

    function cfg_gets(cfg,section,key) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    character(len=:),allocatable:: val
    val=cfg_gets_basic(cfg,section,key)
    val=interpolate_str(cfg,section,val)
    end function
    function cfg_geti(cfg,section,key) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    integer:: val
    call from_string(cfg_gets(cfg,section,key),val)
    end function
    function cfg_getf(cfg,section,key) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(sp):: val
    call from_string(cfg_gets(cfg,section,key),val)
    end function
    function cfg_getd(cfg,section,key) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(dp):: val
    call from_string(cfg_gets(cfg,section,key),val)
    end function
    function cfg_getc(cfg,section,key) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(sp):: val
    call from_string(cfg_gets(cfg,section,key),val)
    end function
    function cfg_getz(cfg,section,key) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(dp):: val
    call from_string(cfg_gets(cfg,section,key),val)
    end function
    function cfg_getb(cfg,section,key) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    logical:: val
    call from_string(cfg_gets(cfg,section,key),val)
    end function

! getter subroutines
    subroutine cfg_get_s(cfg,section,key,val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    character(len=*),intent(out):: val
    val=cfg%gets(section,key)
    end subroutine
    subroutine cfg_get_i(cfg,section,key,val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    integer,intent(out):: val
    val=cfg%geti(section,key)
    end subroutine
    subroutine cfg_get_f(cfg,section,key,val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(sp),intent(out):: val
    val=cfg%getf(section,key)
    end subroutine
    subroutine cfg_get_d(cfg,section,key,val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(dp),intent(out):: val
    val=cfg%getd(section,key)
    end subroutine
    subroutine cfg_get_c(cfg,section,key,val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(sp),intent(out):: val
    val=cfg%getc(section,key)
    end subroutine
    subroutine cfg_get_z(cfg,section,key,val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(dp),intent(out):: val
    val=cfg%getz(section,key)
    end subroutine
    subroutine cfg_get_b(cfg,section,key,val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    logical,intent(out):: val
    val=cfg%getb(section,key)
    end subroutine

! get function optional
    function cfg_gets_opt(cfg,section,key,deflt) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    character(len=*),intent(in):: deflt
    character(len=:),allocatable:: val
    if(cfg%has_key(section,key)) then
        val=cfg%gets(section,key)
    else
        val=trim(deflt)
    endif
    end function
    function cfg_geti_opt(cfg,section,key,deflt) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    integer:: deflt,val
    if(cfg%has_key(section,key)) then
        val=cfg%geti(section,key)
    else
        val=deflt
    endif
    end function
    function cfg_getf_opt(cfg,section,key,deflt) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(sp):: deflt,val
    if(cfg%has_key(section,key)) then
        val=cfg%getf(section,key)
    else
        val=deflt
    endif
    end function
    function cfg_getd_opt(cfg,section,key,deflt) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(dp):: deflt,val
    if(cfg%has_key(section,key)) then
        val=cfg%getf(section,key)
    else
        val=deflt
    endif
    end function
    function cfg_getc_opt(cfg,section,key,deflt) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(sp):: deflt,val
    if(cfg%has_key(section,key)) then
        val=cfg%getc(section,key)
    else
        val=deflt
    endif
    end function
    function cfg_getz_opt(cfg,section,key,deflt) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(dp):: deflt,val
    if(cfg%has_key(section,key)) then
        val=cfg%getz(section,key)
    else
        val=deflt
    endif
    end function
    function cfg_getb_opt(cfg,section,key,deflt) result(val)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    logical:: deflt,val
    if(cfg%has_key(section,key)) then
        val=cfg%getb(section,key)
    else
        val=deflt
    endif
    end function

! getter subroutines optional
    subroutine cfg_get_s_opt(cfg,section,key,val,deflt)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    character(len=*),intent(in):: deflt
    character(len=*),intent(out):: val
    val=cfg%gets(section,key,deflt)
    end subroutine
    subroutine cfg_get_i_opt(cfg,section,key,val,deflt)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    integer,intent(in):: deflt
    integer,intent(out):: val
    val=cfg%geti(section,key,deflt)
    end subroutine
    subroutine cfg_get_f_opt(cfg,section,key,val,deflt)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(sp),intent(in):: deflt
    real(sp),intent(out):: val
    val=cfg%getf(section,key,deflt)
    end subroutine
    subroutine cfg_get_d_opt(cfg,section,key,val,deflt)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(dp),intent(in):: deflt
    real(dp),intent(out):: val
    val=cfg%getd(section,key,deflt)
    end subroutine
    subroutine cfg_get_c_opt(cfg,section,key,val,deflt)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(sp),intent(in):: deflt
    complex(sp),intent(out):: val
    val=cfg%getc(section,key,deflt)
    end subroutine
    subroutine cfg_get_z_opt(cfg,section,key,val,deflt)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(dp),intent(in):: deflt
    complex(dp),intent(out):: val
    val=cfg%getz(section,key,deflt)
    end subroutine
    subroutine cfg_get_b_opt(cfg,section,key,val,deflt)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    logical,intent(in):: deflt
    logical,intent(out):: val
    val=cfg%getb(section,key,deflt)
    end subroutine

! get list

    subroutine get_iarr(cfg,section,key,arr,npar)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    integer,allocatable,intent(out):: arr(:)
    integer,optional:: npar
    integer n,isect,ikey
    call find_sect_key(cfg,section,key,isect,ikey)
    n=list_size(cfg%s(isect)%p(ikey)%val)
    if(present(npar)) npar=n
    if(.not.allocated(arr)) allocate(arr(n))
    read(cfg%s(isect)%p(ikey)%val,*) arr
    end subroutine
    subroutine get_farr(cfg,section,key,arr,npar)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(sp),allocatable,intent(out):: arr(:)
    integer,optional:: npar
    integer n,isect,ikey
    call find_sect_key(cfg,section,key,isect,ikey)
    n=list_size(cfg%s(isect)%p(ikey)%val)
    if(present(npar)) npar=n
    if(.not.allocated(arr)) allocate(arr(n))
    read(cfg%s(isect)%p(ikey)%val,*) arr
    end subroutine
    subroutine get_darr(cfg,section,key,arr,npar)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    real(dp),allocatable,intent(out):: arr(:)
    integer,optional:: npar
    integer n,isect,ikey
    call find_sect_key(cfg,section,key,isect,ikey)
    n=list_size(cfg%s(isect)%p(ikey)%val)
    if(present(npar)) npar=n
    if(.not.allocated(arr)) allocate(arr(n))
    read(cfg%s(isect)%p(ikey)%val,*) arr
    end subroutine
    subroutine get_carr(cfg,section,key,arr,npar)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(sp),allocatable,intent(out):: arr(:)
    integer,optional:: npar
    integer n,isect,ikey
    call find_sect_key(cfg,section,key,isect,ikey)
    n=list_size_cmplx(cfg%s(isect)%p(ikey)%val)
    if(present(npar)) npar=n
    if(.not.allocated(arr)) allocate(arr(n))
    read(cfg%s(isect)%p(ikey)%val,*) arr
    end subroutine
    subroutine get_zarr(cfg,section,key,arr,npar)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    complex(dp),allocatable,intent(out):: arr(:)
    integer,optional:: npar
    integer n,isect,ikey
    call find_sect_key(cfg,section,key,isect,ikey)
    n=list_size_cmplx(cfg%s(isect)%p(ikey)%val)
    if(present(npar)) npar=n
    if(.not.allocated(arr)) allocate(arr(n))
    read(cfg%s(isect)%p(ikey)%val,*) arr
    end subroutine
    subroutine get_barr(cfg,section,key,arr,npar)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    logical,allocatable,intent(out):: arr(:)
    integer,optional:: npar
    integer n,isect,ikey
    call find_sect_key(cfg,section,key,isect,ikey)
    n=list_size(cfg%s(isect)%p(ikey)%val)
    if(present(npar)) npar=n
    if(.not.allocated(arr)) allocate(arr(n))
    read(cfg%s(isect)%p(ikey)%val,*) arr
    end subroutine
    subroutine get_sarr(cfg,section,key,arr,npar)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: section,key
    character(len=*),allocatable,intent(out):: arr(:)
    integer,optional:: npar
    integer n,isect,ikey
    call find_sect_key(cfg,section,key,isect,ikey)
    n=list_size_str(cfg%s(isect)%p(ikey)%val)
    if(present(npar)) npar=n
    if(.not.allocated(arr)) allocate(arr(n))
    read(cfg%s(isect)%p(ikey)%val,*) arr
    end subroutine

! cfg parse
    function parse_cfg(filename) result(cfg)
    type(cfg_t):: cfg
    character(len=*),intent(in):: filename
    character(len=512):: text
    integer:: iunit
    iunit=assign_unit()
    open(iunit,file=filename)
    do
        read(iunit,'(a)',end=999) text
        !print*,"read text:: ",trim(text)
        call parse_text(cfg,trim(text))
    enddo
999 close(iunit)
    end function

    subroutine parse_text(cfg,text)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: text
    character(len=MXNSTR):: key,val
    integer:: id,istat
    character:: cmt1='#',cmt2=';',eq='=',str1
    character(len=MXNSTR):: str
    type(cfg_sect_t):: new_s
    str=adjustl(text)
    str1=str(1:1)
    ! #, ; comment
    if(str1==cmt1 .or. str1==cmt2) return
    ! section title
    if(str1=='[') then
        id=index(str,']')
        if(id==0) call errexit('Wrong section title')
        new_s%section=trim(adjustl(str(2:id-1)))
        allocate(new_s%p(0))
        if(.not.allocated(cfg%s)) allocate(cfg%s(0))
        cfg%s = [cfg%s, new_s]
        !print*,"Section::",cfg%s(cfg%nsect())%section
        return
    endif
    ! parameter
    id=index(str,eq)
    if(id==0) return
    call split_kv(str,key,val)
    !val=unquote(val)
    !print*,"Par::",key,'=',trim(val)
    call addpar(cfg,key,val)
    end subroutine

    subroutine addpar(cfg,key,val)
    class(cfg_t),intent(inout):: cfg
    character(len=*),intent(in):: key,val
    integer:: isect
    type(cfg_sect_t):: new_s
    isect=cfg%nsect()
    ! parameters without section titles go to the defaults section
    if(isect==0) then
        new_s%section=defaults
        allocate(new_s%p(1))
        new_s%p(1)=dict_t(key, val)
        cfg%s = [new_s]
    else
        if(.not. allocated(cfg%s(isect)%p)) allocate(cfg%s(isect)%p(0))
        cfg%s(isect)%p = [cfg%s(isect)%p, dict_t(key, val)]
    endif
    end subroutine

! report
    subroutine print_cfg(cfg,iunit)
    class(cfg_t),intent(in):: cfg
    integer,intent(in),optional:: iunit
    integer i,j,un
    if(present(iunit)) then
        un=iunit
    else
        un=STDOUT
    endif
    if(cfg%nsect()==1) then ! no section title
        i=1
        if(cfg%s(i)%section .ne. defaults) write(un,"('[',a,']')") trim(adjustl(cfg%s(i)%section))
        do j=1,cfg%s(i)%npar()
            write(un,"(a,' = ',a)") trim(cfg%s(i)%p(j)%key),trim(cfg%s(i)%p(j)%val)
        enddo
    else
        do i=1,cfg%nsect()
            write(un,"('[',a,']')") trim(adjustl(cfg%s(i)%section))
            do j=1,cfg%s(i)%npar()
                write(un,"('  ',a,' = ',a)") trim(cfg%s(i)%p(j)%key),trim(cfg%s(i)%p(j)%val)
            enddo
            write(un,*)
        enddo
    endif
    end subroutine
    subroutine write_cfg_file(cfg,filename)
    class(cfg_t),intent(in):: cfg
    character(len=*),intent(in):: filename
    integer un
    un=assign_unit()
    open(un,file=filename)
    call print_cfg(cfg,un)
    close(un)
    end subroutine

!! utils
    subroutine errexit(msg)
    character(len=*),intent(in) :: msg
    write(stderr,*) trim(msg)
    stop
    end subroutine

    function assign_unit() result(un)
    logical :: oflag
    integer :: un,i
    do i=99,10,-1
        inquire(unit=i,opened=oflag)
        if(.not.oflag) then
            un=i
            return
        endif
    enddo
    end function

! parameter key=val parse
    subroutine split_kv(par,key,val)
    character(len=*),intent(in):: par
    character(len=*),intent(out):: key,val
    character:: eq='='
    integer:: id
    id=index(par,eq)
    key=trim(adjustl(par(1:id-1)))
    val=trim(adjustl(par(id+1:)))
    end subroutine

end module

